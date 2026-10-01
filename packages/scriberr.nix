{
  lib,
  stdenvNoCC,
  fetchurl,
  buildFHSEnv,
}:

let
  version = "1.2.0";
  unwrapped = stdenvNoCC.mkDerivation {
    pname = "scriberr-unwrapped";
    inherit version;

    src = fetchurl {
      url = "https://github.com/rishikanthc/Scriberr/releases/download/v${version}/Scriberr_Linux_x86_64.tar.gz";
      hash = "sha256-xfaD4df2DaKR8LbSWEWqz2z3ZM1Gjwusa6QZSs72X1g=";
    };

    sourceRoot = ".";

    installPhase = ''
      runHook preInstall

      install -Dm755 scriberr "$out/bin/scriberr"
      install -Dm644 LICENSE "$out/share/licenses/scriberr/LICENSE"

      runHook postInstall
    '';
  };
in
buildFHSEnv {
  name = "scriberr";
  inherit version;

  # Upstream uses uv to install Python environments and native ML wheels at runtime.
  targetPkgs =
    pkgs: with pkgs; [
      cacert
      deno
      ffmpeg
      gcc
      git
      gnumake
      libGL
      libsndfile
      openssl
      python311
      stdenv.cc.cc
      uv
      yt-dlp
      zlib
    ];

  profile = ''
    export UV_PYTHON="''${UV_PYTHON:-/usr/bin/python3.11}"
    export UV_PYTHON_DOWNLOADS=never
    export LD_LIBRARY_PATH="/run/opengl-driver/lib''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
  '';

  runScript = "${unwrapped}/bin/scriberr";

  passthru = { inherit unwrapped; };

  meta = {
    description = "Self-hosted audio transcription with speaker diarization";
    homepage = "https://github.com/rishikanthc/Scriberr";
    license = lib.licenses.mit;
    mainProgram = "scriberr";
    platforms = [ "x86_64-linux" ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
}
