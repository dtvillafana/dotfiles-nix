{ inputs, ... }:
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
      hyprwhichkey = pkgs.callPackage ../../packages/hyprwhichkey.nix {
        inherit (inputs) hyprwhichkey-src;
      };
      desktopAction = pkgs.writeShellApplication {
        name = "hypr-desktop-action";
        runtimeInputs = with pkgs; [
          astal.io
          coreutils
          gopass
          grim
          jq
          libnotify
          osConfig.programs.hyprland.package
          procps
          fuzzel
          slurp
          systemd
          tesseract
          uwsm
          wl-clipboard
          wtype
          ydotool
        ];
        text = ''
          fuzzel_menu() {
            local cache_name="$1"
            shift
            local cache_dir="''${XDG_CACHE_HOME:-$HOME/.cache}"
            mkdir -p "$cache_dir"
            # Menu labels may include credential names; keep newly written caches private.
            (umask 077; exec fuzzel --dmenu --match-mode=fzf --cache="$cache_dir/fuzzel-$cache_name" "$@")
          }

          case "''${1:-}" in
            menu)
              shift
              fuzzel_menu "$@"
              ;;
            bindings)
              shift
              exec astal -i hyprwhichkey "$@"
              ;;
            run)
              # List executable files from the session PATH, not Bash builtins.
              IFS=: read -r -a path_dirs <<< "$PATH"
              shopt -s nullglob dotglob
              command="$(
                for directory in "''${path_dirs[@]}"; do
                  for program in "''${directory:-.}"/*; do
                    if [ -f "$program" ] && [ -x "$program" ]; then
                      printf '%s\n' "''${program##*/}"
                    fi
                  done
                done | sort -u | fuzzel_menu commands --prompt 'Run command… '
              )" || exit 0
              [ -n "$command" ] || exit 0
              exec uwsm app -- ${lib.getExe pkgs.bash} -c "$command"
              ;;
            palette)
              action="$(printf '%s\n' 'Lock screen' 'Log out' 'Suspend' 'Reboot' 'Power off' | fuzzel_menu system --only-match --prompt 'System actions… ')" || exit 0
              case "$action" in
                'Lock screen') exec loginctl lock-session ;;
                'Log out') exec hypr-desktop-action logout ;;
                'Suspend') exec systemctl suspend ;;
                'Reboot'|'Power off')
                  answer="$(printf '%s\n' 'Cancel' "$action" | fuzzel_menu confirm-power --only-match --select Cancel --prompt "$action? ")" || exit 0
                  [ "$answer" = "$action" ] || exit 0
                  if [ "$action" = Reboot ]; then
                    exec systemctl reboot
                  else
                    exec systemctl poweroff
                  fi
                  ;;
              esac
              ;;
            touchpad-on|touchpad-off)
              enabled=false
              [ "$1" != touchpad-on ] || enabled=true
              hyprctl -j devices | jq -r '.mice[] | select(.name | test("touchpad"; "i")) | .name | @json' |
                while IFS= read -r device; do
                  hyprctl eval "hl.device({ name = $device, enabled = $enabled })"
                done
              ;;
            password|username|otp)
              # Capture the target before fuzzel takes focus. Browsers and Remmina
              # do not consistently honor wtype's temporary virtual keymap.
              target_class="$(hyprctl -j activewindow | jq -r '.class // ""')"
              entry="$(gopass ls --flat | sort | fuzzel_menu credentials --only-match --prompt 'Select credential… ')" || exit 0
              [ -n "$entry" ] || exit 0
              case "$1" in
                password) value="$(gopass show -o "$entry")" ;;
                username) value="''${entry##*/}" ;;
                otp) value="$(gopass otp -o "$entry")" ;;
              esac
              # Let the shortcut modifiers be released before injecting text.
              sleep 0.2
              case "$target_class" in
                *[Rr]emmina*)
                  # Use the configured US layout and pace events for remote sessions.
                  printf '%s' "$value" | ydotool type --key-delay=40 --key-hold=40 --file=-
                  ;;
                *[Bb]rave*|*[Cc]hromium*|*[Cc]hrome*|*[Ff]irefox*|*qutebrowser*)
                  printf '%s' "$value" | ydotool type --key-delay=20 --key-hold=20 --file=-
                  ;;
                *) printf '%s' "$value" | wtype - ;;
              esac
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
                process="$(ps -e -o comm= | sort -u | fuzzel_menu processes-root --only-match --prompt 'Stop process (root)… ')" || exit 0
                [ -n "$process" ] || exit 0
                if ! error="$(/run/wrappers/bin/sudo -n -- ${lib.getExe' pkgs.procps "pkill"} -x -- "$process" 2>&1)"; then
                  notify-send --urgency=critical 'Could not stop process' "''${error:-No matching process remains, or it could not be signalled.}"
                  exit 1
                fi
              else
                process="$(ps -u "$USER" -o comm= | sort -u | fuzzel_menu processes --only-match --prompt 'Stop process… ')" || exit 0
                [ -n "$process" ] || exit 0
                exec pkill -x -- "$process"
              fi
              ;;
            logout)
              answer="$(printf 'Cancel\nLog out\n' | fuzzel_menu confirm-logout --only-match --select Cancel --prompt 'Exit Hyprland? ')" || exit 0
              if [ "$answer" = 'Log out' ]; then
                if uwsm check is-active hyprland; then
                  exec uwsm stop
                else
                  exec hyprctl eval 'hl.dispatch(hl.dsp.exit())'
                fi
              fi
              ;;
            *) echo "Unknown desktop action: ''${1:-}" >&2; exit 1 ;;
          esac
        '';
      };
    in
    {
      imports = [ ./hyprland/_settings.nix ];

      wayland.systemd.target = "graphical-session.target";

      programs.zsh.shellAliases.start-hyprland = "uwsm start hyprland.desktop";

      # All desktop users share the same UWSM-managed Wayland session.
      home.packages = with pkgs; [
        desktopAction
        hyprwhichkey
        grim
        slurp
        wl-clipboard
        swaybg
        dunst
        networkmanagerapplet
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

      xdg.configFile."hypr/user.lua".text = lib.mkDefault "";
      home.pointerCursor = {
        package = pkgs.adwaita-icon-theme;
        name = "Adwaita";
        size = 24;
        gtk.enable = true;
        x11.enable = true;
      };
      # UWSM imports these before starting graphical-session.target and portals.
      xdg.configFile."uwsm/env-hyprland".text = ''
        export NIXOS_OZONE_WL=1
        export XCURSOR_THEME=Adwaita
        export XCURSOR_SIZE=24
      '';

      # Distinct ports allow different users' sessions to coexist on one host.
      # Keep the Dell's existing SSH-tunnel endpoint (5901) for capcu.
      xdg.configFile."wayvnc/config".text = ''
        address=127.0.0.1 ::1
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
          # The SDDM greeter can own the port for several seconds after login.
          # Keep retrying even if startup/hotplug failures exceed systemd's limit.
          StartLimitIntervalSec = 0;
        };
        Service = {
          ExecStart = "${lib.getExe pkgs.wayvnc} --desktop --disable-resizing --config ${config.xdg.configHome}/wayvnc/config";
          Restart = "always";
          RestartSec = 2;
        };
        Install.WantedBy = [ "graphical-session.target" ];
      };
      systemd.user.services.hyprwhichkey = {
        Unit = {
          Description = "Which-key binding overlay for Hyprland";
          After = [ "graphical-session.target" ];
          PartOf = [ "graphical-session.target" ];
          ConditionEnvironment = "WAYLAND_DISPLAY";
        };
        Service = {
          ExecStart = lib.getExe hyprwhichkey;
          Restart = "on-failure";
          RestartSec = 2;
        };
        Install.WantedBy = [ "graphical-session.target" ];
      };

      services.hyprpolkitagent.enable = true;
      services.hypridle = {
        enable = true;
        systemdTarget = "graphical-session.target";
        settings.general = {
          lock_cmd = "pidof hyprlock || hyprlock";
          before_sleep_cmd = "loginctl lock-session";
        };
      };
      programs.hyprlock = {
        enable = true;
        settings = {
          background = {
            monitor = "";
            color = "rgba(000000ff)";
          };
          input-field = {
            monitor = "";
            size = "300, 50";
            position = "0, 0";
            halign = "center";
            valign = "center";
          };
        };
      };

      programs.waybar = {
        enable = true;
        systemd.enable = true;
        systemd.targets = [ "graphical-session.target" ];
        settings.mainBar = {
          layer = "top";
          position = "bottom";
          height = 26;
          on-sigusr1 = "hide";
          on-sigusr2 = "show";
          modules-left = [
            "hyprland/workspaces"
            "hyprland/submap"
          ];
          modules-center = [ "hyprland/window" ];
          modules-right = [
            "custom/keyboard"
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
          "hyprland/window" = {
            align = 0.5;
            format = "{title}";
            max-length = 80;
            separate-outputs = true;
          };
          "custom/keyboard" = {
            format = "⌨";
            tooltip-format = "Toggle keyboard shortcuts (Mod+F1)";
            on-click = "hypr-desktop-action bindings";
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
        style = ''
          * { font-family: "DejaVu Sans Mono"; font-size: 14px; }
          window#waybar { background: #222222; color: #ffffff; }
          #workspaces button { color: #ffffff; padding: 0 8px; border-radius: 0; }
          #workspaces button.active { background: #285577; }
          #custom-keyboard, #network, #disk, #battery, #memory, #pulseaudio, #clock, #tray, #submap, #window { padding: 0 8px; }
        '';
      };
    };
}
