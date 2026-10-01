{
  lib,
  blender,
  curl,
  draco,
  fmt,
  fribidi,
  harfbuzz,
  libsecret,
  meshoptimizer,
  openssl,
  pkg-config,
  mixar-src,
  mixar-blender-src,
}:

blender.overrideAttrs (old: {
  pname = "mixar";
  version = "4.1.4";
  src = mixar-blender-src;

  # Already fixed in Mixar's newer Blender upstream.
  patches = builtins.filter (patch: baseNameOf patch != "fix-quite-clog-warning.patch") old.patches;

  # Mixar replaces selected Blender files before applying nixpkgs' patches.
  prePatch = ''
    cp -r ${mixar-src}/src/. .
    chmod -R u+w .
    substituteInPlace intern/ghost/intern/GHOST_SystemPathsUnix.cc \
      --replace-fail '"/blender/"' '"/mixar/"'

    cat > source/creator/mixar_env_config.h <<'EOF'
    #pragma once
    #define MIXAR_BASE_URL "https://api.mixar.app"
    #define MIXAR_FRONTEND_BASE_URL "https://www.mixar.app"
    #define MIXAR_CURRENT_ENV "Prod"
    #define MIXAR_ENV_PROD
    EOF

    cat > scripts/mixar/config/_build_env.py <<'EOF'
    BUILD_ENVIRONMENT = "Prod"
    DEV_BYPASS_ALLOWED = False
    EOF
  '';

  nativeBuildInputs = old.nativeBuildInputs ++ [ pkg-config ];
  buildInputs = old.buildInputs ++ [
    curl
    draco
    fmt
    fribidi
    harfbuzz
    libsecret
    meshoptimizer
    openssl
  ];
  pythonPath =
    old.pythonPath
    ++ (with blender.pythonPackages; [
      cryptography
      httpx
      keyring
      mistune
      pillow
      truststore
      websocket-client
    ]);

  env = old.env // {
    MIXAR_VERSION = "4.1.4";
    MIXAR_UPDATE_AUTO_DOWNLOAD = "false";
  };

  blenderExecutable = placeholder "out" + "/bin/mixar";
  postInstall = old.postInstall + ''
    # Keep Mixar's inherited manual from colliding with Blender's.
    mv "$out/share/man/man1/blender.1" "$out/share/man/man1/mixar.1"

    resourceDir=$(find "$out/share/mixar" -mindepth 1 -maxdepth 1 -type d)
    python ${mixar-src}/scripts/generate_config.py \
      --output "$resourceDir/config/mixar.json" \
      --version-file ${mixar-src}/VERSION
  '';
  postFixup =
    lib.replaceStrings
      [ "/bin/blender" "/bin/.blender-wrapped" ]
      [
        "/bin/mixar"
        "/bin/.mixar-wrapped"
      ]
      (old.postFixup or "");

  passthru = {
    inherit (blender) python pythonPackages;
  };
  meta = old.meta // {
    description = "AI-powered 3D editor built on Blender";
    homepage = "https://github.com/Mixar-AI/mixar-app";
    license = lib.licenses.gpl3Plus;
    mainProgram = "mixar";
    platforms = [ "x86_64-linux" ];
    maintainers = [ ];
  };
})
