"""Isolated Qt/settings smoke test; never touches a real user or daemon."""

import importlib.util
from pathlib import Path
import sys
import tempfile
import tomllib

from PyQt6.QtWidgets import QApplication


def main() -> None:
    source = Path(sys.argv[1])
    spec = importlib.util.spec_from_file_location("voxtype_tray", source)
    assert spec is not None and spec.loader is not None
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)

    with tempfile.TemporaryDirectory() as directory:
        module.CONFIG_PATH = Path(directory) / "config.toml"
        module.DEFAULT_CONFIG_PATH = Path(directory) / "missing.toml"
        module.MODELS_DIR = Path(directory) / "models"
        module.get_daemon_status = lambda: False
        module.detect_gpu_vendor = lambda: "unknown"
        module.provider_lookup_failed_recently = lambda: False
        module.write_config({
            "engine": "parakeet",
            "hotkey": {"enabled": False, "mode": "toggle"},
            "audio": {"device": "pipewire", "sample_rate": 16000, "max_duration_secs": 120},
            "parakeet": {"model": "parakeet-tdt-0.6b-v3-int8", "streaming": False},
            "output": {"mode": "type"},
            "osd": {"enabled": False},
        })
        app = QApplication([])
        window = module.VoxTypeSettings()
        assert window.engine.currentText() == "parakeet"
        assert window.audio_device.text() == "pipewire"
        assert not window.enable_gpu_btn.isEnabled()
        assert not window.enable_onnx_btn.isEnabled()
        assert module.backend_supports_onnx(module.get_current_backend())

        # Exercise the actual GUI save handler and preserve unmanaged settings.
        window.pre_type_delay.setValue(175)
        window.save_config()
        saved = tomllib.loads(module.CONFIG_PATH.read_text())
        assert saved["output"]["pre_type_delay_ms"] == 175
        assert saved["osd"]["enabled"] is False
        assert saved["hotkey"]["enabled"] is False
        assert saved["audio"]["device"] == "pipewire"
        window.close()
        app.processEvents()
    print("Voxtype tray GUI and config round-trip checks passed")


if __name__ == "__main__":
    main()
