"""Idle gate. Discard input events; never record keys or event contents.

The privileged controller reads input, but downloaded renderers run as sheepit.
No input devices, remote sessions, failed GPU checks, or missing credentials
all inhibit rendering. A controller exit also stops the entire worker cgroup.
"""

import os
from pathlib import Path
import select
import shutil
import subprocess
import time

from evdev import InputDevice, ecodes, list_devices


def command(*args: str) -> str:
    return subprocess.run(
        args, check=True, capture_output=True, text=True, timeout=10
    ).stdout.strip()


def gpu_busy() -> bool:
    for pid in command(
        "nvidia-smi", "--query-compute-apps=pid", "--format=csv,noheader,nounits"
    ).splitlines():
        try:
            groups = Path(f"/proc/{int(pid)}/cgroup").read_text()
        except FileNotFoundError:
            continue
        if "/sheepit.service" not in groups:
            return True
    return False


def remote_session() -> bool:
    for session in command("loginctl", "list-sessions", "--no-legend").splitlines():
        if (
            command(
                "loginctl",
                "show-session",
                session.split()[0],
                "-p",
                "Remote",
                "--value",
            )
            == "yes"
        ):
            return True
    return False


def can_render(
    *,
    has_input: bool,
    has_credentials: bool,
    disabled: bool,
    free_bytes: int,
    blocked: bool,
    idle_for: float,
    idle_seconds: int,
) -> bool:
    return (
        has_input
        and has_credentials
        and not disabled
        and free_bytes >= 10 * 1024**3
        and not blocked
        and idle_for >= idle_seconds
    )


def main() -> None:
    idle_seconds = int(os.environ["SHEEPIT_IDLE_SECONDS"])
    credentials = Path(os.environ["SHEEPIT_CREDENTIALS"])
    devices: dict[str, InputDevice] = {}
    observed_paths: set[str] = set()
    last_activity = time.monotonic()
    last_check = 0.0
    last_start = 0.0
    command("systemctl", "stop", "sheepit.service")
    while True:
        now = time.monotonic()
        boot_time = time.clock_gettime(time.CLOCK_BOOTTIME)
        # A suspend/resume or scheduling gap must begin a fresh idle interval.
        if boot_time - last_check > 15:
            last_activity = now
        last_check = boot_time
        paths = set(list_devices())
        if paths != observed_paths:
            observed_paths = paths
            for device in devices.values():
                device.close()
            devices = {}
            for path in paths:
                device = InputDevice(path)
                if ecodes.EV_KEY in device.capabilities():
                    devices[path] = device
                else:
                    device.close()
            last_activity = now
        readable, _, _ = select.select(list(devices.values()), [], [], 2)
        for device in readable:
            for event in device.read():
                if event.type in (ecodes.EV_KEY, ecodes.EV_REL, ecodes.EV_ABS):
                    last_activity = time.monotonic()
        try:
            blocked = gpu_busy() or remote_session()
        except (OSError, ValueError, subprocess.SubprocessError):
            blocked = True
        if blocked:
            last_activity = time.monotonic()
        eligible = can_render(
            has_input=bool(devices),
            has_credentials=credentials.is_file() and credentials.stat().st_size > 0,
            disabled=Path("/var/lib/sheepit/disabled").exists(),
            free_bytes=shutil.disk_usage("/var/lib/sheepit").free,
            blocked=blocked,
            idle_for=time.monotonic() - last_activity,
            idle_seconds=idle_seconds,
        )
        active = command(
            "systemctl", "show", "sheepit.service", "-p", "ActiveState", "--value"
        )
        if (
            eligible
            and active in ("inactive", "failed")
            and time.monotonic() - last_start >= 60
        ):
            last_start = time.monotonic()
            print("Idle and GPU available: starting SheepIt", flush=True)
            command("systemctl", "start", "--no-block", "sheepit.service")
        elif not eligible and active in ("active", "activating"):
            print("Activity or unavailable resources: stopping SheepIt", flush=True)
            command("systemctl", "stop", "sheepit.service")


if __name__ == "__main__":
    main()
