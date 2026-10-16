import signal
import unittest
from pathlib import Path
from unittest.mock import patch

import monitor

SIGNAL_COMMAND = b"/nix/store/electron/bin/electron\0/nix/store/abc-signal-desktop/share/signal-desktop/app.asar\0"


class MonitorTests(unittest.TestCase):
    def test_connected_remote_desktop_blocks_closure(self) -> None:
        with patch.object(monitor.subprocess, "run") as run:
            run.return_value.stdout = "0 0 127.0.0.1:5902 127.0.0.1:40000\n"
            self.assertTrue(monitor.remote_desktop_connected())
        arguments = run.call_args.args[0]
        self.assertIn("established", arguments)
        self.assertIn("sport = :5902", arguments[-1])
        self.assertNotIn(":22", arguments[-1])

    def test_no_remote_desktop_does_not_block_closure(self) -> None:
        with patch.object(monitor.subprocess, "run") as run:
            run.return_value.stdout = ""
            self.assertFalse(monitor.remote_desktop_connected())

    def test_matches_signal_main_process(self) -> None:
        self.assertTrue(monitor.is_signal(SIGNAL_COMMAND))

    def test_does_not_match_helpers_or_other_apps(self) -> None:
        for command in (
            b"electron\0--type=gpu-process\0--user-data-dir=/home/vir/.config/Signal\0",
            b"electron\0/nix/store/abc-other/share/other/app.asar\0",
            b"electron\0/tmp/share/signal-desktop/app.asar\0",
            b"",
        ):
            with self.subTest(command=command):
                self.assertFalse(monitor.is_signal(command))

    def test_closes_only_signal_and_releases_pidfds(self) -> None:
        with (
            patch.object(
                Path, "iterdir", return_value=iter([Path("/proc/1"), Path("/proc/2")])
            ),
            patch.object(Path, "read_bytes", side_effect=[SIGNAL_COMMAND, b"other\0"]),
            patch.object(monitor.os, "pidfd_open", side_effect=[11, 12]),
            patch.object(monitor.signal, "pidfd_send_signal") as send,
            patch.object(monitor.os, "close") as close,
        ):
            monitor.close_signal()
        send.assert_called_once_with(11, signal.SIGTERM)
        self.assertEqual([call.args for call in close.call_args_list], [(11,), (12,)])

    def test_process_exit_is_harmless(self) -> None:
        with (
            patch.object(Path, "iterdir", return_value=iter([Path("/proc/1")])),
            patch.object(monitor.os, "pidfd_open", side_effect=ProcessLookupError),
        ):
            monitor.close_signal()


if __name__ == "__main__":
    unittest.main()
