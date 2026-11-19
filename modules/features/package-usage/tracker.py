"""Local fanotify accounting for Nix store executables."""

import argparse
import ctypes
import json
import os
import select
import signal
import sqlite3
import struct
import sys
import time
from collections import Counter, defaultdict
from collections.abc import Iterator
from contextlib import contextmanager
from datetime import datetime
from pathlib import Path

STORE = b"/nix/store/"
DEFAULT_DB = Path("/var/lib/nix-package-usage/usage.sqlite")
# Linux UAPI: linux/fanotify.h
FAN_CLOEXEC, FAN_NONBLOCK = 0x01, 0x02
FAN_OPEN_EXEC, FAN_Q_OVERFLOW = 0x1000, 0x4000
FAN_MARK_ADD, FAN_MARK_FILESYSTEM = 0x01, 0x100
EVENT = struct.Struct("=IBBHQii")
Key = tuple[str, str]


def output_root(path: bytes) -> bytes:
    if path.startswith(STORE):
        return STORE + path[len(STORE) :].split(b"/", 1)[0]
    return b""


@contextmanager
def watch() -> Iterator[int]:
    libc = ctypes.CDLL(None, use_errno=True)
    libc.fanotify_init.argtypes = (ctypes.c_uint, ctypes.c_uint)
    libc.fanotify_mark.argtypes = (
        ctypes.c_int,
        ctypes.c_uint,
        ctypes.c_uint64,
        ctypes.c_int,
        ctypes.c_char_p,
    )
    fd = libc.fanotify_init(FAN_CLOEXEC | FAN_NONBLOCK, os.O_RDONLY | os.O_CLOEXEC)
    if fd < 0:
        err = ctypes.get_errno()
        raise OSError(err, f"fanotify_init: {os.strerror(err)}")
    try:
        if (
            libc.fanotify_mark(
                fd, FAN_MARK_ADD | FAN_MARK_FILESYSTEM, FAN_OPEN_EXEC, -100, STORE
            )
            < 0
        ):
            err = ctypes.get_errno()
            raise OSError(err, f"fanotify_mark: {os.strerror(err)}")
        yield fd
    finally:
        os.close(fd)


def read_events(fd: int, counts: Counter[bytes]) -> int:
    dropped = 0
    try:
        data = os.read(fd, 65536)
    except BlockingIOError:
        return 0
    offset = 0
    while offset < len(data):
        length, version, _, _, mask, event_fd, _ = EVENT.unpack_from(data, offset)
        if version != 3 or not EVENT.size <= length <= len(data) - offset:
            raise RuntimeError("Unexpected fanotify event layout")
        offset += length
        if event_fd < 0:
            dropped += bool(mask & (FAN_Q_OVERFLOW | FAN_OPEN_EXEC))
            continue
        try:
            path = os.readlink(b"/proc/self/fd/" + str(event_fd).encode())
            if mask & FAN_OPEN_EXEC and output_root(path):
                counts[path] += 1
        except OSError:
            dropped += 1
        finally:
            os.close(event_fd)
    return dropped


def running_paths() -> set[bytes]:
    paths = set()
    for pid in os.listdir(b"/proc"):
        if pid.isdigit():
            try:
                path = os.readlink(b"/proc/" + pid + b"/exe")
            except OSError:
                continue
            if output_root(path):
                paths.add(path)
    return paths


def inventory(manifest: Path) -> tuple[dict[Key, set[bytes]], dict[Key, set[bytes]]]:
    roots: dict[Key, set[bytes]] = defaultdict(set)
    binaries: dict[Key, set[bytes]] = defaultdict(set)
    for row in json.loads(manifest.read_text()):
        key = row["scope"], row["name"]
        roots[key].update(os.fsencode(path) for path in row["paths"])
    for key, paths in roots.items():
        for path in paths:
            try:
                with os.scandir(path + b"/bin") as entries:
                    for entry in entries:
                        if entry.is_file() and os.access(entry.path, os.X_OK):
                            binaries[key].add(os.path.realpath(entry.path))
            except (FileNotFoundError, NotADirectoryError):
                pass
    return roots, binaries


def collect(db: sqlite3.Connection, manifest: Path) -> None:
    roots, binaries = inventory(manifest)
    db.executescript("""
        CREATE TABLE IF NOT EXISTS seen (
            path BLOB PRIMARY KEY, opens INTEGER NOT NULL, last_seen INTEGER NOT NULL
        );
        CREATE TABLE IF NOT EXISTS aliases (
            scope TEXT, name TEXT, path BLOB, PRIMARY KEY (scope, name, path)
        );
        CREATE TABLE IF NOT EXISTS coverage (
            id INTEGER PRIMARY KEY CHECK (id = 1),
            first_seen INTEGER, last_seen INTEGER, loss INTEGER, seconds REAL
        );
    """)
    stop = False

    def request_stop(_sig: int, _frame: object) -> None:
        nonlocal stop
        stop = True

    signal.signal(signal.SIGINT, request_stop)
    signal.signal(signal.SIGTERM, request_stop)
    with watch() as fd:
        checkpoint = time.monotonic()
        now = int(time.time())
        with db:
            db.execute(
                "INSERT OR IGNORE INTO coverage VALUES (1, ?, ?, 0, 0)", (now, now)
            )
            db.executemany(
                "INSERT OR IGNORE INTO aliases VALUES (?, ?, ?)",
                (
                    (*key, path)
                    for key in roots
                    for path in roots[key]
                    | {p for p in binaries[key] if output_root(p)}
                ),
            )
        counts: Counter[bytes] = Counter(dict.fromkeys(running_paths(), 0))
        dropped = 0
        print("Watching Nix store executions", flush=True)
        while True:
            ready, _, _ = select.select([fd], [], [], 0.5 if not stop else 0)
            if ready:
                dropped += read_events(fd, counts)
            elapsed = time.monotonic() - checkpoint
            if stop or elapsed >= 5:
                now = int(time.time())
                with db:
                    db.executemany(
                        """INSERT INTO seen VALUES (?, ?, ?)
                           ON CONFLICT(path) DO UPDATE SET
                           opens = opens + excluded.opens, last_seen = excluded.last_seen""",
                        ((path, count, now) for path, count in counts.items()),
                    )
                    db.execute(
                        """UPDATE coverage SET last_seen = ?, loss = loss + ?,
                           seconds = seconds + ? WHERE id = 1""",
                        (now, dropped, elapsed),
                    )
                counts.clear()
                dropped = 0
                checkpoint = time.monotonic()
            if stop:
                break


def stamp(when: int) -> str:
    return datetime.fromtimestamp(when).astimezone().strftime("%Y-%m-%d %H:%M %Z")


def report(db: sqlite3.Connection, args: argparse.Namespace) -> None:
    db.execute("BEGIN")
    first, last, loss, seconds = db.execute(
        "SELECT first_seen, last_seen, loss, seconds FROM coverage WHERE id = 1"
    ).fetchone() or (0, 0, 0, 0)
    if not first:
        raise ValueError("No observations yet. Start the collector first.")
    print(f"Collecting since {stamp(first)}; last checkpoint {stamp(last)}.")
    print(f"Collector time: {seconds / 3600:.1f} hours (not necessarily continuous).")
    if loss:
        print(f"Warning: {loss} queue-overflow or unreadable-event notifications.")
    if time.time() - last > 30:
        print("Warning: collector has not checked in recently.")
    if seconds < 30 * 86400 and not args.executed:
        print("Early data: give this about a month of normal use before pruning.")

    seen = {
        path: (opens, when) for path, opens, when in db.execute("SELECT * FROM seen")
    }
    if args.executed:
        print("\n     OPENS  LAST OBSERVED          EXECUTABLE")
        for path, (opens, when) in sorted(
            seen.items(), key=lambda item: (-item[1][0], item[0])
        ):
            print(f"{opens:10d}  {stamp(when):21}  {os.fsdecode(path)!r}")
        return

    roots, binaries = inventory(args.manifest)
    aliases: dict[bytes, set[Key]] = defaultdict(set)
    for scope, name, path in db.execute("SELECT * FROM aliases"):
        if (scope, name) in roots:
            aliases[path].add((scope, name))
    for key in roots:
        for path in roots[key] | binaries[key]:
            aliases[path].add(key)

    last_used: dict[Key, int] = defaultdict(int)
    totals: Counter[Key] = Counter()
    for path, (opens, when) in seen.items():
        for key in aliases.get(path, set()) | aliases.get(output_root(path), set()):
            last_used[key] = max(last_used[key], when)
            totals[key] += opens

    rows = sorted(roots, key=lambda key: (last_used[key], key))
    print(
        "\nSCOPE               PACKAGE                       LAST OBSERVED / EXEC OPENS"
    )
    for scope, name in rows:
        key = scope, name
        when = last_used[key]
        if args.binaries:
            for path in sorted(binaries[key]):
                if path not in seen:
                    print(
                        f"{scope:19} {name:29} {os.fsdecode(path)!r} (unseen current binary)"
                    )
        elif args.all or (not when and binaries[key]):
            status = f"{stamp(when)} / {totals[key]}" if when else "not observed"
            if not when and not binaries[key]:
                status = "not observed; no executable bin entries"
            print(f"{scope:19} {name:29} {status}")
    print("\nNo observation is not proof a package is safe to remove.")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest", type=Path, required=True)
    parser.add_argument("--db", type=Path, default=DEFAULT_DB)
    commands = parser.add_subparsers(dest="command", required=True)
    commands.add_parser("collect", help="run the privileged collector")
    options = commands.add_parser(
        "report", help="list packages with binaries but no observations"
    )
    views = options.add_mutually_exclusive_group()
    views.add_argument("--all", action="store_true", help="include observed packages")
    views.add_argument(
        "--binaries", action="store_true", help="list unseen current package binaries"
    )
    views.add_argument(
        "--executed", action="store_true", help="list all recorded executable paths"
    )
    args = parser.parse_args()
    try:
        if args.command == "collect":
            with sqlite3.connect(args.db) as db:
                collect(db, args.manifest)
        else:
            with sqlite3.connect(
                args.db.resolve().as_uri() + "?mode=ro", uri=True
            ) as db:
                report(db, args)
    except (OSError, sqlite3.Error, RuntimeError, ValueError) as exc:
        sys.exit(f"nix-package-usage: {exc}")


if __name__ == "__main__":
    main()
