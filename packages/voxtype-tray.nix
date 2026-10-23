{
  lib,
  stdenvNoCC,
  python3,
  qt6,
  makeWrapper,
  systemd,
  pciutils,
  voxtype,
  voxtype-tray-src,
}:
let
  python = python3.withPackages (ps: [ ps.pyqt6 ]);
in
stdenvNoCC.mkDerivation {
  pname = "voxtype-tray";
  version = "unstable-2026-08-21";
  src = voxtype-tray-src;

  nativeBuildInputs = [
    makeWrapper
    qt6.wrapQtAppsHook
  ];
  buildInputs = [
    qt6.qtbase
    qt6.qtwayland
  ];
  dontWrapQtApps = true;
  dontBuild = true;

  # Backend switching writes /usr/bin on conventional distros. Nix owns the
  # binary and its ONNX support; only user settings/models are mutable here.
  postPatch = ''
    substituteInPlace voxtype-tray.py \
      --replace-fail 'def get_current_backend() -> str:' 'def get_current_backend() -> str:
        if os.environ.get("VOXTYPE_NIX_MANAGED") == "1":
            return "voxtype-onnx-nix"' \
      --replace-fail '    def _refresh_backend_status(self):' '    def _refresh_backend_status(self):
            if os.environ.get("VOXTYPE_NIX_MANAGED") == "1":
                self.backend_status_label.setText("Backend managed by Nix: ONNX / CPU")
                for button in (self.enable_gpu_btn, self.enable_onnx_btn):
                    button.setEnabled(False)
                    button.setToolTip("Change backend support in your Nix configuration.")
                self.fix_migraphx_btn.setVisible(False)
                return' \
      --replace-fail '        """Run a privileged voxtype subcommand via pkexec, then restart daemon."""' '        """Run a privileged voxtype subcommand via pkexec, then restart daemon."""
            if os.environ.get("VOXTYPE_NIX_MANAGED") == "1":
                QMessageBox.information(self, "Nix-managed backend", "Change backend support in your Nix configuration.")
                return False' \
      --replace-fail 'config.get("whisper", {}).get("gpu_isolation", True)' 'config.get("whisper", {}).get("gpu_isolation", False)' \
      --replace-fail '"gpu_isolation", default=True' '"gpu_isolation", default=False'
  '';

  installPhase = ''
    runHook preInstall
    install -Dm644 voxtype-tray.py "$out/share/voxtype-tray/voxtype-tray.py"
    install -Dm644 voxtype-tray.desktop "$out/share/applications/voxtype-tray.desktop"
    substituteInPlace "$out/share/applications/voxtype-tray.desktop" \
      --replace-fail 'Exec=voxtype-tray' "Exec=$out/bin/voxtype-tray"
    makeWrapper ${python}/bin/python "$out/bin/voxtype-tray" \
      --add-flags "$out/share/voxtype-tray/voxtype-tray.py" \
      --prefix PATH : ${
        lib.makeBinPath [
          voxtype
          systemd
          pciutils
        ]
      } \
      --set VOXTYPE_NIX_MANAGED 1 \
      "''${qtWrapperArgs[@]}"
    runHook postInstall
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    makeWrapper ${python}/bin/python "$TMPDIR/test-voxtype-tray" \
      --add-flags ${./voxtype-tray-test.py} \
      --set HOME "$TMPDIR" \
      --set QT_QPA_PLATFORM offscreen \
      --set VOXTYPE_NIX_MANAGED 1 \
      "''${qtWrapperArgs[@]}"
    "$TMPDIR/test-voxtype-tray" "$out/share/voxtype-tray/voxtype-tray.py"
    runHook postInstallCheck
  '';

  meta = {
    description = "Settings GUI and system tray for Voxtype dictation";
    homepage = "https://github.com/matt-shearing/voxtype-tray";
    license = lib.licenses.mit;
    mainProgram = "voxtype-tray";
    platforms = lib.platforms.linux;
  };
}
