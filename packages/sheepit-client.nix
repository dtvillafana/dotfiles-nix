{
  lib,
  fetchurl,
  buildFHSEnv,
  writeShellScript,
  ...
}:
let
  client = fetchurl {
    url = "https://www.sheepit-renderfarm.com/media/image/news/sheepit-client-7.26132.jar";
    hash = "sha256-LPtsdFXHI7Hbkis40zCw2deDH42yfK6IPrU1eWDRwAc=";
  };
in
buildFHSEnv {
  pname = "sheepit-client";
  version = "7.26132";
  targetPkgs =
    p: with p; [
      jdk17_headless
      glibc
      zlib
      zstd
      stdenv.cc.cc.lib
      libGL
      libx11
      libxext
      libxi
      libxrender
      libxxf86vm
      libxfixes
      libxkbcommon
      libsm
      libice
      libxcb
      wayland
      systemd
      numactl
      openssl
      cacert
    ];
  runScript = writeShellScript "sheepit-client" ''
    export LD_LIBRARY_PATH=/run/opengl-driver/lib:/run/opengl-driver-32/lib:''${LD_LIBRARY_PATH:-}
    exec java -jar ${client} "$@"
  '';
  meta = {
    description = "Pinned legacy SheepIt client for Pascal GPUs and pre-AVX CPUs";
    homepage = "https://www.sheepit-renderfarm.com";
    license = lib.licenses.gpl2Only;
    platforms = [ "x86_64-linux" ];
    mainProgram = "sheepit-client";
  };
}
