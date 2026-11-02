{ inputs, ... }:
{
  flake.homeModules.hokum =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      # Override Hokum's older Rune pin with the revision in our flake lock.
      runeRev = inputs.hokum-rune-src.rev;
      upstreamRuneRev =
        (builtins.fromTOML (builtins.readFile "${inputs.hokum}/Cargo.toml")).dependencies.rune.rev;
      cargoLockFile = ./_hokum/Cargo.lock;
      lockedRune =
        lib.findFirst (package: package.name == "rune") null
          (builtins.fromTOML (builtins.readFile cargoLockFile)).package;
      hokum =
        assert lockedRune.source == "git+https://github.com/anomalyco/rune.git?rev=${runeRev}#${runeRev}";
        inputs.hokum.packages.${pkgs.stdenv.hostPlatform.system}.default.overrideAttrs (old: {
          doCheck = false;
          cargoDeps = pkgs.rustPlatform.importCargoLock {
            lockFile = cargoLockFile;
            allowBuiltinFetchGit = true;
          };
          postPatch = (old.postPatch or "") + ''
            substituteInPlace Cargo.toml \
              --replace-fail ${lib.escapeShellArg upstreamRuneRev} ${lib.escapeShellArg runeRev}
            cp ${cargoLockFile} Cargo.lock
          '';
        });
    in
    {
      key = "dotfiles-nix-hokum";
      home.packages = [ hokum ];
      # Hokum's settings UI and DND command rewrite the live configuration.
      xdg.configFile."hokum/config.kdl" = {
        enable = false;
        text = ''
          behaviour {
              check-for-updates #false
          }
        '';
      };
      home.activation.initializeHokumConfig =
        lib.hm.dag.entryBetween [ "linkGeneration" ] [ "writeBoundary" ]
          ''
            run ${pkgs.writeShellScript "initialize-hokum-config" ''
              set -eu
              settings=${lib.escapeShellArg "${config.xdg.configHome}/hokum/config.kdl"}
              mkdir -p "$(dirname "$settings")"
              if [ -L "$settings" ]; then
                case "$(readlink -f "$settings")" in
                  /nix/store/*)
                    # Preserve settings while replacing the old managed symlink.
                    temporary=$(mktemp "$settings.XXXXXX")
                    trap 'rm -f "$temporary"' EXIT
                    install -m 0600 "$settings" "$temporary"
                    mv -T "$temporary" "$settings"
                    ;;
                esac
              elif [ ! -e "$settings" ]; then
                install -m 0600 ${config.xdg.configFile."hokum/config.kdl".source} "$settings"
              fi
            ''}
          '';
      systemd.user.services.hokum = {
        Unit = {
          Description = "Hokum notifications, sound and Bluetooth";
          After = [ "graphical-session.target" ];
          PartOf = [ "graphical-session.target" ];
          Conflicts = [
            "mako.service"
            "dunst.service"
            "swaync.service"
          ];
          ConditionEnvironment = "WAYLAND_DISPLAY";
          StartLimitIntervalSec = 60;
          StartLimitBurst = 5;
        };
        Service = {
          Type = "dbus";
          BusName = "org.freedesktop.Notifications";
          ExecStart = "${lib.getExe hokum} service";
          Restart = "on-failure";
          RestartPreventExitStatus = 78;
          RestartSec = 2;
        };
        Install.WantedBy = [ "graphical-session.target" ];
      };
      xdg.dataFile."dbus-1/services/org.freedesktop.Notifications.service".text = ''
        [D-BUS Service]
        Name=org.freedesktop.Notifications
        Exec=${lib.getExe hokum} service
        SystemdService=hokum.service
      '';
    };
}
