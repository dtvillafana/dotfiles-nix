"""Exercise credential routing without injecting keys or using real credentials."""

import os
import subprocess
import tempfile
import unittest
from pathlib import Path

SCRIPT = Path(__file__).with_name("type-credential.sh")
MOCKS = r"""
set -euo pipefail
source "$1"
sleep() { command sleep 0.01; }
wtype() {
  printf '%s\n' "$@" > "$TEST_DIR/wtype.args"
  cat > "$TEST_DIR/typed"
}
ydotool() {
  printf '%s\n' "$@" > "$TEST_DIR/ydotool.args"
  if [ "$1" = type ]; then cat > "$TEST_DIR/typed"; fi
}
timeout() {
  [ "$1" = 5s ]
  shift
  "$@"
}
wl-copy() {
  printf '%s\n' "$@" > "$TEST_DIR/wl-copy.args"
  if [ "${FAIL_CLIPBOARD:-0}" = 1 ]; then return 1; fi
  cat > "$TEST_DIR/clipboard"
  command sleep 0.2
  return 124
}
notify-send() { printf '%s\n' "$@" > "$TEST_DIR/notification"; }
type_credential "$2"
"""


class TypeCredentialTests(unittest.TestCase):
    def run_typing(
        self, target: str, value: str, *, fail_clipboard: bool = False
    ) -> tuple[int, dict[str, str]]:
        with tempfile.TemporaryDirectory() as directory:
            result = subprocess.run(
                ["bash", "-c", MOCKS, "test", str(SCRIPT), target],
                input=value,
                text=True,
                capture_output=True,
                check=False,
                env={
                    **os.environ,
                    "TEST_DIR": directory,
                    "FAIL_CLIPBOARD": str(int(fail_clipboard)),
                },
                timeout=5,
            )
            self.assertEqual(result.stdout, "")
            self.assertEqual(result.stderr, "")
            files = {path.name: path.read_text() for path in Path(directory).iterdir()}
            return result.returncode, files

    def test_ascii_uses_existing_key_timings(self) -> None:
        for target, delay in [("firefox", 10), ("org.remmina.Remmina", 20)]:
            with self.subTest(target=target):
                code, files = self.run_typing(target, "test-user!123")
                self.assertEqual(code, 0)
                self.assertEqual(files["typed"], "test-user!123")
                self.assertEqual(
                    files["ydotool.args"],
                    f"type\n--key-delay={delay}\n--key-hold={delay}\n--file=-\n",
                )
                self.assertNotIn("clipboard", files)

    def test_unicode_pastes_whole_value_without_credentials_in_argv(self) -> None:
        for target in [
            "firefox",
            "Brave-browser",
            "org.remmina.Remmina",
            "virt-manager",
        ]:
            with self.subTest(target=target):
                value = "Peña-Ñ-é-漢字-🔑\n"
                code, files = self.run_typing(target, value)
                self.assertEqual(code, 0)
                self.assertEqual(files["clipboard"], value)
                self.assertEqual(
                    files["wl-copy.args"],
                    "--foreground\n--type\ntext/plain;charset=utf-8\n",
                )
                self.assertIn("29:1\n47:1\n47:0\n29:0\n", files["ydotool.args"])
                self.assertNotIn("typed", files)
                for name, contents in files.items():
                    if name.endswith(".args"):
                        self.assertNotIn(value, contents)

    def test_native_wayland_keeps_wtype_unicode(self) -> None:
        code, files = self.run_typing("foot", "Peña-Ñ")
        self.assertEqual(code, 0)
        self.assertEqual(files, {"wtype.args": "-\n", "typed": "Peña-Ñ"})

    def test_clipboard_failure_does_not_paste_stale_contents(self) -> None:
        code, files = self.run_typing("firefox", "Peña", fail_clipboard=True)
        self.assertEqual(code, 1)
        self.assertIn("notification", files)
        self.assertNotIn("ydotool.args", files)


if __name__ == "__main__":
    unittest.main()
