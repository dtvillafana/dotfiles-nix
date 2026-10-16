import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from bridge import atomic_write, coordinates, request, toggle


class BridgeTests(unittest.TestCase):
    def test_normalized_coordinates_with_negative_monitor_origin(self):
        window = {"at": [-1920, 120], "size": [1280, 720]}
        self.assertEqual(coordinates({"x": -1280, "y": 480}, window), (0.5, 0.5))

    def test_outside_window_clamps(self):
        window = {"at": [100, 200], "size": [800, 600]}
        self.assertEqual(coordinates({"x": -100, "y": 2000}, window), (0, 1))

    def test_zero_size_is_rejected(self):
        with self.assertRaises(ValueError):
            coordinates({"x": 0, "y": 0}, {"at": [0, 0], "size": [0, 10]})

    def test_toggle_locks_window_until_disabled(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            with patch("bridge.request", return_value={"address": "0x123"}) as query:
                toggle(root)
                self.assertEqual((root / "target").read_text(), "0x123")
                toggle(root)
                self.assertFalse((root / "target").exists())
                query.assert_called_once_with("activewindow")

    def test_no_active_window_does_not_enable(self):
        with tempfile.TemporaryDirectory() as directory:
            with patch("bridge.request", return_value={}):
                toggle(Path(directory))
            self.assertFalse((Path(directory) / "target").exists())

    def test_atomic_write_replaces_snapshot(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "snapshot"
            atomic_write(path, "first")
            atomic_write(path, "second")
            self.assertEqual(path.read_text(), "second")
            self.assertFalse(path.with_suffix(".tmp").exists())

    def test_hyprland_ipc_request(self):
        with (
            patch.dict(
                "os.environ",
                {
                    "XDG_RUNTIME_DIR": "/runtime",
                    "HYPRLAND_INSTANCE_SIGNATURE": "instance",
                },
            ),
            patch("bridge.socket.socket") as factory,
        ):
            connection = factory.return_value.__enter__.return_value
            connection.recv.side_effect = [b'{"x": 12,', b'"y": 34}', b""]
            self.assertEqual(request("cursorpos"), {"x": 12, "y": 34})
            connection.connect.assert_called_once_with(
                "/runtime/hypr/instance/.socket.sock"
            )
            connection.sendall.assert_called_once_with(b"j/cursorpos")


if __name__ == "__main__":
    unittest.main()
