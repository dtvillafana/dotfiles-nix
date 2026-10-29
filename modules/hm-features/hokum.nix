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
      upstreamHokum = inputs.hokum.packages.${pkgs.stdenv.hostPlatform.system}.default;
      hokum = pkgs.symlinkJoin {
        name = "hokum-${upstreamHokum.version}";
        paths = [ upstreamHokum ];
        nativeBuildInputs = [ pkgs.makeWrapper ];
        # Rune scans XDG_DATA_DIRS/*/fonts directly, not fontconfig's store paths.
        postBuild = ''
          wrapProgram "$out/bin/hokum" \
            --prefix XDG_DATA_DIRS : ${
              lib.makeSearchPath "share" [
                pkgs.dejavu_fonts
                pkgs.noto-fonts
                pkgs.noto-fonts-cjk-sans
                pkgs.noto-fonts-color-emoji
              ]
            }
        '';
        inherit (upstreamHokum) meta;
      };
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
