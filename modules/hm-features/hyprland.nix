{ ... }:
{
  flake.homeModules.hyprland =
    {
      lib,
      pkgs,
      nixvim,
      system,
      osConfig,
      config,
      ...
    }:
    let
      desktopAction = pkgs.writeShellApplication {
        name = "hypr-desktop-action";
        runtimeInputs = with pkgs; [
          coreutils
          gopass
          grim
          jq
          osConfig.programs.hyprland.package
          polkit
          procps
          rofi
          slurp
          tesseract
          uwsm
          wl-clipboard
          wtype
          ydotool
        ];
        text = ''
          case "''${1:-}" in
            touchpad-on|touchpad-off)
              enabled=false
              [ "$1" != touchpad-on ] || enabled=true
              hyprctl -j devices | jq -r '.mice[] | select(.name | test("touchpad"; "i")) | .name | @json' |
                while IFS= read -r device; do
                  hyprctl eval "hl.device({ name = $device, enabled = $enabled })"
                done
              ;;
            password|username|otp)
              entry="$(gopass ls --flat | rofi -dmenu -matching fuzzy -i -sort)" || exit 0
              [ -n "$entry" ] || exit 0
              case "$1" in
                password) value="$(gopass show -o "$entry")" ;;
                username) value="''${entry##*/}" ;;
                otp) value="$(gopass otp -o "$entry")" ;;
              esac
              # Let the shortcut modifiers be released before injecting text.
              sleep 0.2
              printf '%s' "$value" | wtype -
              ;;
            screenshot|ocr)
              geometry="$(slurp)" || exit 0
              if [ "$1" = ocr ]; then
                grim -g "$geometry" - | tesseract stdin stdout | wl-copy
              else
                grim -g "$geometry" - | wl-copy --type image/png
              fi
              ;;
            kill-user|kill-root)
              if [ "$1" = kill-root ]; then
                process="$(ps -e -o comm= | sort -u | rofi -dmenu -matching fuzzy -i -sort)" || exit 0
                [ -n "$process" ] || exit 0
                exec pkexec ${lib.getExe' pkgs.procps "pkill"} -x "$process"
              else
                process="$(ps -u "$USER" -o comm= | sort -u | rofi -dmenu -matching fuzzy -i -sort)" || exit 0
                [ -n "$process" ] || exit 0
                exec pkill -x "$process"
              fi
              ;;
            logout)
              answer="$(printf 'Cancel\nLog out\n' | rofi -dmenu -i -p 'Exit Hyprland?')" || exit 0
              if [ "$answer" = 'Log out' ]; then
                exec uwsm stop
              fi
              ;;
            *) echo "Unknown desktop action: ''${1:-}" >&2; exit 1 ;;
          esac
        '';
      };
    in
    {
      # All desktop users share the same UWSM-managed Wayland session.
      home.packages = with pkgs; [
        desktopAction
        grim
        slurp
        wl-clipboard
        swaybg
        hypridle
        hyprlock
        waybar
        hyprpolkitagent
        dunst
        networkmanagerapplet
        rofi
        wtype
        wdisplays
        wayvnc
        (writeShellApplication {
          name = "xdg-open";
          runtimeInputs = [ systemd ];
          text = ''
            # Restore the current UWSM session for detached tmux/agent shells.
            # Never guess :0: XWayland's display number is session-specific.
            if [ -z "''${DISPLAY:-}" ] && [ -z "''${WAYLAND_DISPLAY:-}" ]; then
              while IFS= read -r variable; do
                case "$variable" in
                  DISPLAY=*|WAYLAND_DISPLAY=*|XDG_CURRENT_DESKTOP=*|XDG_SESSION_TYPE=*|DBUS_SESSION_BUS_ADDRESS=*)
                    export "''${variable?}"
                    ;;
                esac
              done < <(systemctl --user show-environment)
            fi
            exec ${lib.getExe' pkgs.xdg-utils "xdg-open"} "$@"
          '';
        })
        (writeShellScriptBin "hypr-neovide" ''
          exec ${lib.getExe pkgs.neovide} --neovim-bin ${lib.getExe nixvim.packages.${system}.default} "$@"
        '')
      ];

      xdg.configFile."hypr/hyprland.lua".source = ./hyprland/config.lua;
      xdg.configFile."hypr/user.lua".text = lib.mkDefault "";
      # UWSM imports these before starting graphical-session.target and portals.
      xdg.configFile."uwsm/env-hyprland".text = ''
        export NIXOS_OZONE_WL=1
        export XCURSOR_SIZE=24
        export HYPRCURSOR_SIZE=24
      '';

      # Distinct ports allow different users' sessions to coexist on one host.
      # Keep the Dell's existing SSH-tunnel endpoint (5901) for capcu.
      xdg.configFile."wayvnc/config".text = ''
        address=127.0.0.1
        port=${
          toString (
            if config.home.username == "capcu" then
              (if osConfig.networking.hostName == "capcuDell" then 5901 else 5900)
            else if config.home.username == "vir" then
              5902
            else
              5903
          )
        }
        enable_auth=false
      '';
      systemd.user.services.wayvnc = {
        Unit = {
          Description = "Share the Hyprland desktop over localhost-only VNC";
          After = [ "graphical-session.target" ];
          PartOf = [ "graphical-session.target" ];
          ConditionEnvironment = "WAYLAND_DISPLAY";
        };
        Service = {
          ExecStart = "${lib.getExe pkgs.wayvnc} --desktop --disable-resizing --config ${config.xdg.configHome}/wayvnc/config";
          Restart = "on-failure";
          RestartSec = 2;
        };
        Install.WantedBy = [ "graphical-session.target" ];
      };

      systemd.user.services.hyprpolkitagent = {
        Unit = {
          Description = "Hyprland PolicyKit authentication agent";
          After = [ "graphical-session.target" ];
          PartOf = [ "graphical-session.target" ];
        };
        Service.ExecStart = "${pkgs.hyprpolkitagent}/libexec/hyprpolkitagent";
        Install.WantedBy = [ "graphical-session.target" ];
      };
      xdg.configFile."hypr/hypridle.conf".text = ''
        general {
          lock_cmd = pidof hyprlock || hyprlock
          before_sleep_cmd = loginctl lock-session
        }
      '';
      xdg.configFile."hypr/hyprlock.conf".text = ''
        background {
          monitor =
          color = rgba(000000ff)
        }
        input-field {
          monitor =
          size = 300, 50
          position = 0, 0
          halign = center
          valign = center
        }
      '';

      xdg.configFile."waybar/config".text = builtins.toJSON {
        layer = "top";
        position = "bottom";
        height = 26;
        on-sigusr1 = "hide";
        on-sigusr2 = "show";
        modules-left = [
          "hyprland/workspaces"
          "hyprland/submap"
        ];
        modules-right = [
          "network"
          "disk"
          "battery"
          "memory"
          "pulseaudio"
          "clock"
          "tray"
        ];
        "hyprland/workspaces" = {
          format = "{name}";
          all-outputs = false;
        };
        network = {
          format-wifi = "W: {essid} ({signalStrength}%) {ipaddr}";
          format-ethernet = "E: {ipaddr}";
          format-disconnected = "Network: down";
        };
        disk.format = "{free}";
        battery.format = "BAT: {capacity}% {time}";
        memory.format = "Tax Fraud Docs: {used:0.1f} GiB";
        pulseaudio.format = "VOL: {volume}%";
        clock = {
          format = "{:%Y-%m-%d %H:%M:%S}";
          interval = 1;
        };
      };
      xdg.configFile."waybar/style.css".text = ''
        * { font-family: "DejaVu Sans Mono"; font-size: 14px; }
        window#waybar { background: #222222; color: #ffffff; }
        #workspaces button { color: #ffffff; padding: 0 8px; border-radius: 0; }
        #workspaces button.active { background: #285577; }
        #network, #disk, #battery, #memory, #pulseaudio, #clock, #tray, #submap { padding: 0 8px; }
      '';
    };
}
