{
  lib,
  rustPlatform,
  makeWrapper,
  browse-cli-src,
}:

rustPlatform.buildRustPackage {
  pname = "browse";
  version =
    (builtins.fromTOML (builtins.readFile "${browse-cli-src}/rust/Cargo.toml"))
    .workspace.package.version;
  src = browse-cli-src;
  sourceRoot = "source/rust";

  cargoLock.lockFile = "${browse-cli-src}/rust/Cargo.lock";
  nativeBuildInputs = [ makeWrapper ];
  # Upstream integration tests need a browser and a writable home directory.
  doCheck = false;

  postInstall = ''
    wrapProgram "$out/bin/browse" \
      --set OPENCODE_BROWSER_AUTO_UPDATE off
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
  };
}
