{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  makeWrapper,
  makeDesktopItem,
  libxkbcommon,
  wayland,
  vulkan-loader,
  libX11,
  libxcb,
  libXcursor,
  libXi,
  systemd,
  wl-clipboard,
  xdg-utils,
  hokum-release,
}:
let
  release = (builtins.fromJSON (builtins.readFile hokum-release)).release;
  target = release.targets.linux-x64;
in
stdenv.mkDerivation {
  pname = "hokum";
  version = release.version;
  src = fetchurl {
    url = "https://anoma.ly${target.url}";
    sha256 = target.sha256;
  };
  dontUnpack = true;
  nativeBuildInputs = [
    autoPatchelfHook
    makeWrapper
  ];
  buildInputs = [
    libxkbcommon
    stdenv.cc.cc.lib
  ];
  # Rune loads the display and Vulkan libraries dynamically.
  runtimeDependencies = map lib.getLib [
    wayland
    vulkan-loader
    libxkbcommon
    libX11
    libxcb
    libXcursor
    libXi
  ];

  installPhase = ''
    runHook preInstall
    install -Dm755 "$src" "$out/bin/hokum"
    mkdir -p "$out/share/applications"
    cp ${
      makeDesktopItem {
        name = "hokum";
        desktopName = "Hokum";
        comment = "Notifications, sound and Bluetooth for Wayland";
        exec = "hokum";
        categories = [ "Settings" ];
      }
    }/share/applications/* "$out/share/applications/"
    wrapProgram "$out/bin/hokum" \
      --prefix PATH : ${
        lib.makeBinPath [
          systemd
          wl-clipboard
          xdg-utils
        ]
      }
    runHook postInstall
  '';

  meta = {
    description = "Wayland notification daemon and control center";
    homepage = "https://github.com/anomalyco/hokum";
    license = lib.licenses.mit;
    mainProgram = "hokum";
    platforms = [ "x86_64-linux" ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
}
