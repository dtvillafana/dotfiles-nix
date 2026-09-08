{
  lib,
  stdenvNoCC,
  fetchurl,
}:

stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "open-browser-use";
  version = "0.1.42";

  src = fetchurl {
    url = "https://github.com/iFurySt/open-browser-use/releases/download/v${finalAttrs.version}/open-browser-use-cli-${finalAttrs.version}-linux-amd64.tar.gz";
    hash = "sha256-83AeArB45msXCbCSh7HsCB8u6f6Em2MJm6Qp5CQBEUk=";
  };

  sourceRoot = ".";

  installPhase = ''
    runHook preInstall

    install -Dm755 open-browser-use "$out/bin/open-browser-use"
    ln -s open-browser-use "$out/bin/obu"

    runHook postInstall
  '';

  meta = {
    description = "Browser automation native host and CLI";
    homepage = "https://github.com/iFurySt/open-browser-use";
    license = lib.licenses.mit;
    mainProgram = "open-browser-use";
    platforms = [ "x86_64-linux" ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
})
