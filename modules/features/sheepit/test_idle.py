"""Test system-query policy without reading real input devices."""

import importlib.util
from pathlib import Path
import subprocess
import sys
from types import ModuleType
import unittest
from unittest.mock import patch

stub = ModuleType("evdev")
stub.InputDevice = object
stub.ecodes = object()
stub.list_devices = lambda: []
sys.modules.setdefault("evdev", stub)
spec = importlib.util.spec_from_file_location(
    "idle", Path(__file__).with_name("idle.py")
)
idle = importlib.util.module_from_spec(spec)
spec.loader.exec_module(idle)


class IdleTests(unittest.TestCase):
    def test_idle_gate(self) -> None:
        ready = dict(
            has_input=True,
            has_credentials=True,
            disabled=False,
            free_bytes=20 * 1024**3,
            blocked=False,
            idle_for=900,
            idle_seconds=900,
        )
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
        with patch.object(idle, "command", side_effect=["1 1000 vir seat0", "yes"]):
            self.assertTrue(idle.remote_session())

    def test_local_session_is_allowed(self) -> None:
        with patch.object(idle, "command", side_effect=["1 1000 vir seat0", "no"]):
            self.assertFalse(idle.remote_session())

    def test_failed_gpu_query_is_not_silently_available(self) -> None:
        with patch.object(
            idle, "command", side_effect=subprocess.TimeoutExpired("nvidia-smi", 10)
        ):
            with self.assertRaises(subprocess.TimeoutExpired):
                idle.gpu_busy()


if __name__ == "__main__":
    unittest.main()
