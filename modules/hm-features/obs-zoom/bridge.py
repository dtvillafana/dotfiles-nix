"""Expose Hyprland window-relative pointer coordinates to OBS without X11."""

from __future__ import annotations

import argparse
import fcntl
import json
import os
import socket
import time
from pathlib import Path
from typing import Any


def request(command: str) -> Any:
    runtime = Path(os.environ["XDG_RUNTIME_DIR"])
    signature = os.environ["HYPRLAND_INSTANCE_SIGNATURE"]
    with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as connection:
        connection.settimeout(0.5)
        connection.connect(str(runtime / "hypr" / signature / ".socket.sock"))
        connection.sendall(f"j/{command}".encode())
        chunks = []
        while chunk := connection.recv(65536):
            chunks.append(chunk)
    return json.loads(b"".join(chunks))


def coordinates(
    cursor: dict[str, float], window: dict[str, Any]
) -> tuple[float, float]:
    """Logical coordinates cancel display scaling when normalized to the window."""
    x, y = window["at"]
    width, height = window["size"]
    if width <= 0 or height <= 0:
        raise ValueError("Window has no drawable area")
    return (
        min(1.0, max(0.0, (cursor["x"] - x) / width)),
        min(1.0, max(0.0, (cursor["y"] - y) / height)),
    )


def atomic_write(path: Path, text: str) -> None:
    temporary = path.with_suffix(".tmp")
    temporary.write_text(text)
    temporary.replace(path)


def toggle(directory: Path) -> None:
    with (directory / "lock").open("w") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        target = directory / "target"
        if target.exists():
            target.unlink()
        else:
            address = request("activewindow").get("address")
            if address:
                atomic_write(target, address)


def run(directory: Path) -> None:
    # Never resume magnification from a previous graphical session/service run.
    (directory / "target").unlink(missing_ok=True)
    snapshot = directory / "snapshot"
    try:
        while True:
            started = time.monotonic()
            output = "0 0.5 0.5\n"
            try:
                target = directory / "target"
                address = target.read_text() if target.exists() else None
                if address:
                    window = next(
                        (
                            client
                            for client in request("clients")
                            if client["address"] == address
                        ),
                        None,
                    )
                    if (
                        window
                        and window.get("mapped", False)
                        and not window.get("hidden", False)
                    ):
                        x, y = coordinates(request("cursorpos"), window)
                        output = f"1 {x:.8f} {y:.8f}\n"
            except (OSError, ValueError, KeyError, StopIteration):
                # A closed window or unavailable compositor must unzoom OBS.
                pass
            atomic_write(snapshot, f"{output.strip()} {time.monotonic():.6f}\n")
            time.sleep(max(0, 1 / 30 - (time.monotonic() - started)))
    finally:
        snapshot.unlink(missing_ok=True)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--toggle", action="store_true")
    args = parser.parse_args()
    directory = Path(os.environ["XDG_RUNTIME_DIR"]) / "obs-hyprland-zoom"
    directory.mkdir(mode=0o700, exist_ok=True)
    if args.toggle:
        toggle(directory)
    else:
        run(directory)


if __name__ == "__main__":
    main()
