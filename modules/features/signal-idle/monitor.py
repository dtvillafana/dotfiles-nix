"""Close Signal on user inactivity; discard input without recording its contents."""

import json
import os
import select
import signal
import subprocess
import time
from pathlib import Path

from evdev import InputDevice, ecodes, list_devices

IDLE_SECONDS = 30 * 60


def remote_desktop_connected() -> bool:
    # Match established server-side connections, including localhost SSH
    # tunnels. Merely running WayVNC or keeping an SSH shell open isn't activity.
    # VNC ports correspond to the per-user defaults in hyprland.nix.
    return bool(
        subprocess.run(
            [
                "ss",
                "-Htn",
                "state",
                "established",
                "( sport = :5900 or sport = :5902 or sport = :5903 or sport = :3389 )",
            ],
            check=True,
            capture_output=True,
            text=True,
            timeout=10,
        ).stdout.strip()
    )


def is_signal(command_line: bytes) -> bool:
    # Match only the main Nix-packaged Signal process, not Electron GPU helpers
    # or unrelated applications whose arguments happen to mention Signal.
    arguments = command_line.split(b"\0")
    return (
        len(arguments) > 1
        and arguments[1].startswith(b"/nix/store/")
        and arguments[1].endswith(b"/share/signal-desktop/app.asar")
    )


def close_signal() -> None:
    for process in Path("/proc").iterdir():
        if not process.name.isdecimal():
            continue
        try:
            # Open a pidfd first so PID reuse cannot target a different process.
            fd = os.pidfd_open(int(process.name))
            try:
                if is_signal((process / "cmdline").read_bytes()):
                    signal.pidfd_send_signal(fd, signal.SIGTERM)
                    print(
                        f"Idle for 30 minutes: closing Signal ({process.name})",
                        flush=True,
                    )
            finally:
                os.close(fd)
        except (FileNotFoundError, ProcessLookupError, PermissionError):
            continue


def main() -> None:
    ignored = set(json.loads(os.environ.get("SIGNAL_IDLE_IGNORED_DEVICES", "[]")))
    devices: dict[str, InputDevice] = {}
    observed: set[str] = set()
    last_activity = time.monotonic()
    last_check = 0.0
    while True:
        now = time.monotonic()
        boot_time = time.clock_gettime(time.CLOCK_BOOTTIME)
        if boot_time - last_check > 15:
            last_activity = now
        last_check = boot_time
        paths = set(list_devices())
        if paths != observed:
            observed = paths
            for device in devices.values():
                device.close()
            devices = {}
            for path in paths:
                device = None
                try:
                    device = InputDevice(path)
                    if (
                        device.name not in ignored
                        and ecodes.EV_KEY in device.capabilities()
                    ):
                        devices[path] = device
                    else:
                        device.close()
                except OSError:
                    if device is not None:
                        device.close()
            last_activity = now
        readable, _, _ = select.select(list(devices.values()), [], [], 2)
        for device in readable:
            try:
                for event in device.read():
                    if event.type in (ecodes.EV_KEY, ecodes.EV_REL, ecodes.EV_ABS):
                        last_activity = time.monotonic()
            except BlockingIOError:
                continue
            except OSError:
                device.close()
                del devices[device.path]
                observed.discard(device.path)
                last_activity = time.monotonic()
        try:
            blocked = remote_desktop_connected()
        except (OSError, ValueError, subprocess.SubprocessError):
            blocked = True
        if blocked or not devices:
            last_activity = time.monotonic()
        if time.monotonic() - last_activity >= IDLE_SECONDS:
            close_signal()
            # Check again every 30 minutes if Signal is restarted while idle.
            last_activity = time.monotonic()


if __name__ == "__main__":
    main()
