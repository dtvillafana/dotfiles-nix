{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  buildFHSEnv,
  dejavu_fonts,
  dpkg,
  fontconfig,
  icu,
  libICE,
  libGL,
  libSM,
  libX11,
  libXcursor,
  libXext,
  libXi,
  libXrandr,
  openssl,
}:

let
  unwrapped = stdenv.mkDerivation (finalAttrs: {
    pname = "excise-unwrapped";
    version = "3.9.1";

    src = fetchurl {
      url = "https://github.com/marctjones/excise/releases/download/v${finalAttrs.version}/excise_${finalAttrs.version}_amd64.deb";
      hash = "sha256-kQS2HrI/FESUBZBqFmw+3mRO2fOh7etlqaHp/zBDT6g=";
    };

    nativeBuildInputs = [
      autoPatchelfHook
      dpkg
    ];

    runtimeDependencies = map lib.getLib [
      fontconfig
      icu
      libICE
      libSM
      libX11
      stdenv.cc.cc
    ];

    dontUnpack = true;

    installPhase = ''
      runHook preInstall

      dpkg-deb -x "$src" "$out"
      mv "$out/usr/"* "$out/"
      rmdir "$out/usr"
      ln -sfn ../lib/excise/excise "$out/bin/excise"
      substituteInPlace "$out/share/applications/excise.desktop" \
        --replace-fail "/usr/lib/excise/Excise.App" "$out/lib/excise/Excise.App"

      runHook postInstall
    '';
  });
in
buildFHSEnv {
  name = "excise-gui";

  targetPkgs = _pkgs: [
    dejavu_fonts
    fontconfig
    icu
    libICE
    libGL
    libSM
    libX11
    libXcursor
    libXext
    libXi
    libXrandr
    openssl
  ];

  runScript = "${unwrapped}/lib/excise/Excise.App";

  extraInstallCommands = ''
    ln -s ${unwrapped}/bin/excise "$out/bin/excise"
    cp -r ${unwrapped}/share "$out/share"
    chmod -R u+w "$out/share"
    substituteInPlace "$out/share/applications/excise.desktop" \
      --replace-fail "${unwrapped}/lib/excise/Excise.App" "$out/bin/excise-gui"
  '';

  meta = {
    description = "PDF editor with true content-level redaction";
    homepage = "https://github.com/marctjones/excise";
    license = lib.licenses.mit;
    mainProgram = "excise-gui";
    platforms = [ "x86_64-linux" ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
}
