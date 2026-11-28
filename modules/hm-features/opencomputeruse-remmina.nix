{ self, ... }:
{
  flake.homeModules.opencomputeruse-remmina =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      remminaBridge = pkgs.runCommand "opencomputeruse-remmina-bridge" { } ''
        mkdir -p "$out"
        cp ${./_opencomputeruse-remmina.py} "$out/_opencomputeruse-remmina.py"
        cp ${./_opencomputeruse-remmina.html} "$out/_opencomputeruse-remmina.html"
      '';

      opencomputeruse = pkgs.stdenvNoCC.mkDerivation (finalAttrs: {
        pname = "opencomputeruse";
        version = "0.11.1";
        src = pkgs.fetchurl {
          url = "https://github.com/IAmJSD/OpenComputerUse/releases/download/v${finalAttrs.version}/opencomputeruse-linux-x86_64";
          hash = "sha256-rAN8HflQFPCZon+xp8BwsbsYnyKrHj14JubDtkVTGAE=";
        };
        nativeBuildInputs = [ pkgs.autoPatchelfHook ];
        buildInputs = [
          pkgs.libxcb
          pkgs.libxkbcommon
          pkgs.pixman
          pkgs.stdenv.cc.cc.lib
        ];
        dontUnpack = true;
        installPhase = ''
          runHook preInstall
          install -Dm755 "$src" "$out/bin/opencomputeruse"
          runHook postInstall
        '';
        meta.mainProgram = "opencomputeruse";
      });

      remminaClosure = pkgs.closureInfo { rootPaths = [ pkgs.remmina ]; };
      launchRemmina = pkgs.writeShellScript "remmina" ''
        set -eu
        umask 077
        profile=${lib.escapeShellArg "${config.xdg.dataHome}/opencomputeruse-remmina"}
        ${lib.getExe' pkgs.coreutils "mkdir"} -p -- "$profile"

        store_mounts=()
        while IFS= read -r path; do
          store_mounts+=(--ro-bind "$path" "$path")
        done < ${remminaClosure}/store-paths

        # Only the private compositor and accessibility bus are exposed.
        bus_path=''${AT_SPI_BUS_ADDRESS#unix:path=}
        bus_path=''${bus_path%%,*}
        test -S "$bus_path"
        test -S "$WAYLAND_DISPLAY"

        exec ${lib.getExe pkgs.bubblewrap} \
          --unshare-all --unshare-user --share-net --disable-userns \
          --new-session --die-with-parent --clearenv \
          "''${store_mounts[@]}" \
          --proc /proc --dev /dev --tmpfs /tmp \
          --ro-bind /etc/hosts /etc/hosts \
          --ro-bind /etc/resolv.conf /etc/resolv.conf \
          --ro-bind /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt \
          --perms 0700 --dir /run/ocu \
          --ro-bind "$WAYLAND_DISPLAY" /run/ocu/wayland-0 \
          --ro-bind "$bus_path" /run/ocu/at-spi \
          --bind "$profile" /home/remmina --chdir /home/remmina \
          --setenv HOME /home/remmina \
          --setenv XDG_RUNTIME_DIR /run/ocu \
          --setenv GDK_BACKEND wayland \
          --setenv WAYLAND_DISPLAY wayland-0 \
          --setenv AT_SPI_BUS_ADDRESS unix:path=/run/ocu/at-spi \
          --setenv GSETTINGS_BACKEND memory \
          --setenv LANG C.UTF-8 \
          ${lib.getExe pkgs.remmina}
      '';
    in
    {
      imports = [ self.homeModules.ai ];

      home.packages = [
        (pkgs.writeShellScriptBin "remmina-agent-view" ''
          exec ${lib.getExe pkgs.python3} ${remminaBridge}/_opencomputeruse-remmina.py --open-view \
            ${lib.getExe' pkgs.xdg-utils "xdg-open"}
        '')
      ];

      opencode.exclusiveMcpServers.opencomputeruse = {
        type = "local";
        command = [
          (lib.getExe pkgs.python3)
          "${remminaBridge}/_opencomputeruse-remmina.py"
          (lib.getExe opencomputeruse)
          launchRemmina
          (lib.makeBinPath [ pkgs.dbus ])
          "${pkgs.xkeyboard_config}/share/X11/xkb"
        ];
        codemode = false;
      };
    };
}
