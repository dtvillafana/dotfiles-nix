"""Test system-query policy without reading real input devices."""

import importlib.util
import subprocess
import sys
import unittest
from pathlib import Path
from types import ModuleType
from unittest.mock import Mock, patch

stub = ModuleType("evdev")
stub.InputDevice = object
stub.ecodes = Mock(EV_KEY=1, EV_REL=2, EV_ABS=3)
stub.list_devices = list
sys.modules.setdefault("evdev", stub)
spec = importlib.util.spec_from_file_location(
    "idle", Path(__file__).with_name("idle.py")
)
idle = importlib.util.module_from_spec(spec)
spec.loader.exec_module(idle)


class IdleTests(unittest.TestCase):
    def test_idle_gate(self) -> None:
        ready = {
            "has_input": True,
            "has_credentials": True,
            "disabled": False,
            "free_bytes": 20 * 1024**3,
            "blocked": False,
            "idle_for": 900,
            "idle_seconds": 900,
        }
        self.assertTrue(idle.can_render(**ready))
        for reason in (
            {"has_input": False},
            {"has_credentials": False},
            {"disabled": True},
            {"free_bytes": 9 * 1024**3},
            {"blocked": True},
            {"idle_for": 899},
        ):
            with self.subTest(reason=reason):
                self.assertFalse(idle.can_render(**(ready | reason)))

    def test_gpu_without_compute_processes_is_available(self) -> None:
        with patch.object(idle, "command", return_value=""):
            self.assertFalse(idle.gpu_busy())

    def test_other_gpu_workload_blocks_rendering(self) -> None:
        with (
            patch.object(idle, "command", return_value="123"),
            patch.object(
                Path, "read_text", return_value="0::/system.slice/ollama.service\n"
            ),
        ):
            self.assertTrue(idle.gpu_busy())

    def test_own_renderer_does_not_block_itself(self) -> None:
        with (
            patch.object(idle, "command", return_value="123"),
            patch.object(
                Path, "read_text", return_value="0::/system.slice/sheepit.service\n"
            ),
        ):
            self.assertFalse(idle.gpu_busy())

    def test_process_exit_race_is_safe(self) -> None:
        with (
            patch.object(idle, "command", return_value="123"),
            patch.object(Path, "read_text", side_effect=FileNotFoundError),
        ):
            self.assertFalse(idle.gpu_busy())

    def test_remote_session_blocks_rendering(self) -> None:
        with patch.object(
            idle,
            "command",
            side_effect=["1 1000 vir seat0", "Remote=yes\nState=active"],
        ):
            self.assertTrue(idle.remote_session())

    def test_local_session_is_allowed(self) -> None:
        with patch.object(
            idle, "command", side_effect=["1 1000 vir seat0", "Remote=no\nState=active"]
        ):
            self.assertFalse(idle.remote_session())

    def test_closing_remote_session_is_allowed(self) -> None:
        with patch.object(
            idle, "command", side_effect=["6 1000 vir", "Remote=yes\nState=closing"]
        ):
            self.assertFalse(idle.remote_session())

    def test_online_remote_session_blocks_after_closing_session(self) -> None:
        with patch.object(
            idle,
            "command",
            side_effect=[
                "6 1000 vir\n7 1000 vir",
                "Remote=yes\nState=closing",
                "Remote=yes\nState=online",
            ],
        ):
            self.assertTrue(idle.remote_session())

    def test_ignored_input_device_is_closed(self) -> None:
        device = Mock()
        device.name = "Noisy controller"
        with patch.object(idle, "InputDevice", return_value=device):
            self.assertEqual(
                idle.input_devices({"/dev/input/event1"}, {"Noisy controller"}), {}
            )
        device.close.assert_called_once()
        device.capabilities.assert_not_called()

    def test_keyboard_is_monitored(self) -> None:
        device = Mock()
        device.name = "Keyboard"
        device.capabilities.return_value = {1: []}
        with (
            patch.object(idle, "InputDevice", return_value=device),
            patch.object(idle, "ecodes", Mock(EV_KEY=1)),
        ):
            self.assertEqual(
                idle.input_devices({"/dev/input/event1"}, {"Noisy controller"}),
                {"/dev/input/event1": device},
            )
        device.close.assert_not_called()

    def test_device_disappearing_during_open_is_safe(self) -> None:
        with patch.object(idle, "InputDevice", side_effect=FileNotFoundError):
            self.assertEqual(idle.input_devices({"/dev/input/event1"}, set()), {})

    def test_device_disappearing_during_capabilities_is_closed(self) -> None:
        device = Mock()
        device.name = "Keyboard"
        device.capabilities.side_effect = OSError(19, "No such device")
        with patch.object(idle, "InputDevice", return_value=device):
            self.assertEqual(idle.input_devices({"/dev/input/event1"}, set()), {})
        device.close.assert_called_once()

    def test_read_disconnect_and_empty_read_race_are_safe(self) -> None:
        for error in (OSError(19, "No such device"), BlockingIOError()):
            with self.subTest(error=error):
                device = Mock(path="/dev/input/event1")
                device.read.side_effect = error
                with (
                    patch.dict(
                        idle.os.environ,
                        SHEEPIT_IDLE_SECONDS="900",
                        SHEEPIT_CREDENTIALS="/nonexistent/sheepit-test-credentials",
                    ),
                    patch.object(idle, "list_devices", return_value=[device.path]),
                    patch.object(
                        idle, "input_devices", return_value={device.path: device}
                    ),
                    patch.object(
                        idle.select,
                        "select",
                        side_effect=[([device], [], []), StopIteration],
                    ),
                    patch.object(idle, "gpu_busy", return_value=False),
                    patch.object(idle, "remote_session", return_value=False),
                    patch.object(
                        idle.shutil, "disk_usage", return_value=Mock(free=20 * 1024**3)
                    ),
                    patch.object(idle, "command", return_value="inactive"),
                    self.assertRaises(StopIteration),
                ):
                    idle.main()
                if isinstance(error, BlockingIOError):
                    device.close.assert_not_called()
                else:
                    device.close.assert_called_once()

    def test_failed_gpu_query_is_not_silently_available(self) -> None:
        with (
            patch.object(
                idle, "command", side_effect=subprocess.TimeoutExpired("nvidia-smi", 10)
            ),
            self.assertRaises(subprocess.TimeoutExpired),
        ):
            idle.gpu_busy()


if __name__ == "__main__":
    unittest.main()
