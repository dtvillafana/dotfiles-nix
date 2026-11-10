{
  lib,
  stdenv,
  makeWrapper,
  formatelf,
  browse-cli-src,
}:

stdenv.mkDerivation {
  pname = "browse";
  version = "0.0.16";
  src = browse-cli-src;

  nativeBuildInputs = [
    formatelf
    makeWrapper
  ];
  buildInputs = [ stdenv.cc.cc.lib ];
  dontBuild = true;
  # Preserve the Bun executable's embedded payload when fixing up its ELF.
  dontStrip = true;

  installPhase = ''
    runHook preInstall
    install -Dm755 bin/browse "$out/bin/browse"
    wrapProgram "$out/bin/browse" \
      --set OPENCODE_BROWSER_AUTO_UPDATE off
    runHook postInstall
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    test "$("$out/bin/browse" --version)" = "$version"
    runHook postInstallCheck
  '';

  meta = {
    description = "Drive your existing Chromium browser through an MCP server and extension";
    homepage = "https://github.com/anomalyco/browse";
    license = lib.licenses.mit;
    mainProgram = "browse";
    platforms = [ "x86_64-linux" ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
}
