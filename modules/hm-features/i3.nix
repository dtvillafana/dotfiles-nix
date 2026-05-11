{ ... }:
{
  flake.homeModules.i3 =
    {
      lib,
      nixvim,
      system,
      pkgs,
      ...
    }:
    {
      xsession = {
        enable = true;
        initExtra = ''
          rm -f ~/.cache/rofi3.druncache ~/.cache/rofi3.runcache
        '';
        scriptPath = ".xinitrc";
        windowManager = {
          i3 = {
            enable = true;
            config = {
              modifier = "Mod4";
              terminal = "ghostty";
              fonts = {
                names = [
                  "DejaVu Sans Mono"
                ];
                style = "Normal";
                size = 11.0;
              };
              bars = [
                {
                  fonts = {
                    names = [
                      "DejaVu Sans Mono"
                      "-misc-fixed-medium-r-normal--13-120-75-75-C-70-iso10646-1"
                    ];
                    size = 11.0;
                  };
                  statusCommand = lib.getExe pkgs.i3status;
                }
              ];
              assigns = {
                "$web" = [
                  { class = "qutebrowser"; }
                  { class = "Brave-browser"; }
                  { class = "brave-browser"; }
                ];
                "$terms" = [
                  { class = "org.wezfurlong.wezterm"; }
                  { class = "wezterm"; }
                  { class = "ghostty"; }
                  { class = "com.mitchellh.ghostty"; }
                ];
                "$media" = [
                  { class = "vlc"; }
                ];
                "$comms" = [
                  { class = "Signal"; }
                  { class = "TelegramDesktop"; }
                  { class = "Microsoft Teams - Preview"; }
                ];
                "$docs" = [
                  { class = "Zathura"; }
                  { class = "libreoffice"; }
                  { class = "kolourpaint"; }
                  { class = "soffice"; }
                  { class = "Soffice"; }
                  { class = "libreoffice"; }
                  { class = "libreoffice-impress"; }
                ];
                "$DB" = [
                  { class = "sqlitebrowser"; }
                  { class = "DB Browser for SQLite"; }
                ];
                "$VMs" = [
                  { class = "Virt-manager"; }
                ];
                "$misc" = [
                  { class = "pavucontrol"; }
                  { class = ".arandr-wrapped"; }
                ];
              };

              floating.modifier = "Mod4";
              focus.mouseWarping = false;
              workspaceAutoBackAndForth = true;

              modes = {
                resize = {
                  "h" = "resize shrink width 10 px or 10 ppt";
                  "j" = "resize grow height 10 px or 10 ppt";
                  "k" = "resize shrink height 10 px or 10 ppt";
                  "l" = "resize grow width 10 px or 10 ppt";
                  "Left" = "resize shrink width 10 px or 10 ppt";
                  "Down" = "resize grow height 10 px or 10 ppt";
                  "Up" = "resize shrink height 10 px or 10 ppt";
                  "Right" = "resize grow width 10 px or 10 ppt";
                  "Return" = "mode default";
                  "Escape" = "mode default";
                  "$mod+r" = "mode default";
                };
                "$mode_system" = {
                  "l" = "exec --no-startup-id ${lib.getExe pkgs.i3lock} -c 000000, mode default";
                  "e" = "exec --no-startup-id i3-msg exit, mode default";
                  "r" = "exec --no-startup-id sudo reboot, mode default";
                  "s" = "exec --no-startup-id sudo poweroff, mode default";
                  "Return" = "mode default";
                  "Escape" = "mode default";
                };
                "$mode_i3bar" = {
                  "$mod+h" = "exec i3-msg bar mode hide";
                  "$mod+Shift+h" = "exec i3-msg bar mode dock";
                  "Escape" = "mode default";
                };
                "$mouseMover" = {
                  "c" = "mode default";
                  "Escape" = "mode default";
                  "space" = "exec xdotool click 1 ; mode default";
                  "enter" = "exec xdotool click 1 ; mode default";
                  "i" = "exec xdotool click 1";
                  "shift+space" = "exec xdotool click 3";
                  "shift+i" = "exec xdotool click 3";
                  "o" = "exec xdotool click 4";
                  "p" = "exec xdotool click 5";
                  "h" = "exec xdotool mousemove_relative -- -200 0";
                  "j" = "exec xdotool mousemove_relative 0 200";
                  "k" = "exec xdotool mousemove_relative 0 -200";
                  "l" = "exec xdotool mousemove_relative 200 0";
                  "shift+h" = "exec xdotool mousemove_relative -- -18 0";
                  "shift+j" = "exec xdotool mousemove_relative 0 18";
                  "shift+k" = "exec xdotool mousemove_relative 0 -18";
                  "shift+l" = "exec xdotool mousemove_relative 18 0";
                };
                "$mode_workspaces" = {
                  "l" = "move workspace to output right";
                  "h" = "move workspace to output left";
                  "Return" = "mode default";
                  "Escape" = "mode default";
                };
              };

              keybindings =
                let
                  mod = "Mod4";
                  mode_system = "System (l) lock, (e) logout, (s) shutdown, (r) reboot";
                  mouseMover = "Mouse movement : quit(c)|move(hjkl)|move less(shift+hjkl)|click(i)|click&exit(spacebar/enter)|right click(shift+spacebar/I)|scroll(o/p)";
                  mode_i3bar = "i3bar: hide (mod+h) unhide (mod+shift+h)";
                  mode_workspaces = "(h) move workspace left, (l) move workspace right";
                  refresh_i3status = "killall -SIGUSR1 i3status";
                  terms = "terminals";
                  web = "web";
                  docs = "documents";
                  media = "media";
                  comms = "comms";
                  VMs = "VMs";
                  DB = "DB";
                  ssh = "SSH";
                  misc = "misc";
                  termsbk = "Background Processes";
                in
                {
                  "${mod}+Shift+Return" = "exec ${pkgs.neovide}/bin/neovide --neovim-bin ${
                    lib.getExe nixvim.packages.${system}.default
                  }";
                  "${mod}+Return" = "exec ${pkgs.ghostty}/bin/ghostty";
                  "${mod}+Shift+t" = "exec i3-sensible-terminal";
                  "${mod}+Shift+q" = "kill";
                  "${mod}+d" = "exec rofi -show drun";
                  "${mod}+g" =
                    "exec gopass ls --flat | rofi -dmenu -matching fuzzy -i -sort | xargs --no-run-if-empty gopass show -o | xdotool type --clearmodifiers --file -";
                  "${mod}+u" =
                    "exec gopass ls --flat | rofi -dmenu -matching fuzzy -i -sort | awk -F\"/\" \"NF{print \\$NF}\" | xdotool type --clearmodifiers --file -";
                  "${mod}+o" =
                    "exec gopass ls --flat | rofi -dmenu -matching fuzzy -i -sort | xargs --no-run-if-empty gopass otp -o | xdotool type --clearmodifiers --file -";
                  "${mod}+minus" =
                    "exec --no-startup-id brightnessctl set 5%- && notify-send -t 300 \"`brightnessctl | grep -E '[0-9]{2}%' `\"";
                  "${mod}+plus" =
                    "exec --no-startup-id brightnessctl set +5% && notify-send -t 300 \"`brightnessctl | grep -E '[0-9]{2}%' `\"";
                  "${mod}+p" = "exec xinput --disable \"$(xinput | awk -F = '/TouchPad/{print $2}' | cut -b 1-2)\"";
                  "${mod}+Shift+p" =
                    "exec xinput --enable \"$(xinput | awk -F = '/TouchPad/{print $2}' | cut -b 1-2)\"";
                  "${mod}+Shift+s" =
                    "exec --no-startup-id sh -c 'env DISPLAY=$DISPLAY ${pkgs.scrot}/bin/scrot -s /tmp/screenshot.png && env DISPLAY=$DISPLAY ${pkgs.xclip}/bin/xclip -selection clipboard -t image/png < /tmp/screenshot.png && rm /tmp/screenshot.png'";
                  "${mod}+h" = "focus left";
                  "${mod}+j" = "focus down";
                  "${mod}+shift+a" =
                    "exec --no-startup-id sh -c 'setxkbmap -query | grep -q swapcaps && setxkbmap -option || setxkbmap -option ctrl:swapcaps'";
                  "${mod}+k" = "focus up";
                  "${mod}+l" = "focus right";
                  "${mod}+Left" = "focus left";
                  "${mod}+Down" = "focus down";
                  "${mod}+Up" = "focus up";
                  "${mod}+Right" = "focus right";
                  "${mod}+Shift+h" = "move left";
                  "${mod}+Shift+j" = "move down";
                  "${mod}+Shift+k" = "move up";
                  "${mod}+Shift+l" = "move right";
                  "${mod}+Shift+Left" = "move left";
                  "${mod}+Shift+Down" = "move down";
                  "${mod}+Shift+Up" = "move up";
                  "${mod}+Shift+Right" = "move right";
                  "${mod}+b" = "split h";
                  "${mod}+v" = "split v";
                  "${mod}+f" = "fullscreen toggle";
                  "${mod}+s" = "layout stacking";
                  "${mod}+w" = "layout tabbed";
                  "${mod}+e" = "layout toggle split";
                  "${mod}+Shift+space" = "floating toggle";
                  "${mod}+space" = "focus mode_toggle";
                  "${mod}+a" = "focus parent";
                  "${mod}+BackSpace" = "mode \"${mode_system}\"";
                  "${mod}+i" = "mode \"${mode_i3bar}\"";
                  "${mod}+c" = "mode \"${mouseMover}\"";
                  "${mod}+m" = "mode \"${mode_workspaces}\"";
                  "${mod}+1" = "workspace ${terms}";
                  "${mod}+2" = "workspace ${web}";
                  "${mod}+3" = "workspace ${docs}";
                  "${mod}+4" = "workspace ${media}";
                  "${mod}+5" = "workspace ${comms}";
                  "${mod}+6" = "workspace ${VMs}";
                  "${mod}+7" = "workspace ${DB}";
                  "${mod}+8" = "workspace ${ssh}";
                  "${mod}+9" = "workspace ${misc}";
                  "${mod}+0" = "workspace ${termsbk}";
                  "${mod}+Shift+1" = "move container to workspace ${terms}";
                  "${mod}+Shift+2" = "move container to workspace ${web}";
                  "${mod}+Shift+3" = "move container to workspace ${docs}";
                  "${mod}+Shift+4" = "move container to workspace ${media}";
                  "${mod}+Shift+5" = "move container to workspace ${comms}";
                  "${mod}+Shift+6" = "move container to workspace ${VMs}";
                  "${mod}+Shift+7" = "move container to workspace ${DB}";
                  "${mod}+Shift+8" = "move container to workspace ${ssh}";
                  "${mod}+Shift+9" = "move container to workspace ${misc}";
                  "${mod}+Shift+0" = "move container to workspace ${termsbk}";
                  "${mod}+Shift+c" = "reload";
                  "${mod}+Shift+r" = "restart";
                  "${mod}+Ctrl+r" = ''exec --no-startup-id i3-input -F 'title_format "%s"' -P 'New title: ' '';
                  "${mod}+Shift+e" =
                    "exec i3-nagbar -t warning -m 'You pressed the exit shortcut. Do you really want to exit i3? This will end your X session.' -B 'Yes, exit i3' 'i3-msg exit'";
                  "${mod}+r" = "mode resize";
                  "XF86AudioRaiseVolume" =
                    "exec --no-startup-id pactl set-sink-volume @DEFAULT_SINK@ +10% && ${refresh_i3status}";
                  "XF86AudioLowerVolume" =
                    "exec --no-startup-id pactl set-sink-volume @DEFAULT_SINK@ -10% && ${refresh_i3status}";
                  "XF86AudioMute" =
                    "exec --no-startup-id pactl set-sink-mute @DEFAULT_SINK@ toggle && ${refresh_i3status}";
                  "XF86AudioMicMute" =
                    "exec --no-startup-id pactl set-source-mute @DEFAULT_SOURCE@ toggle && ${refresh_i3status}";
                };

              startup = [
                {
                  command = "--no-startup-id xss-lock --transfer-sleep-lock -- ${lib.getExe pkgs.i3lock} --nofork";
                }
                { command = "--no-startup-id nm-applet"; }
                { command = "dunst &"; }
                { command = "--no-startup-id feh --no-fehbg --bg-fill '~/pictures/wallpaper.jpg'"; }
              ];
            };
            extraConfig = ''
              # Define workspace variables
              set $terms "terminals"
              set $web "web"
              set $docs "documents"
              set $media "media"
              set $comms "comms"
              set $VMs "VMs"
              set $DB "DB"
              set $ssh "SSH"
              set $misc "misc"
              set $termsbk "Background Processes"

              # Define mode variables
              set $mode_system System (l) lock, (e) logout, (s) shutdown, (r) reboot
              set $mode_i3bar i3bar: hide (mod+h) unhide (mod+shift+h)
              set $mouseMover Mouse movement : quit(c)|move(hjkl)|move less(shift+hjkl)|click(i)|click&exit(spacebar/enter)|right click(shift+spacebar/I)|scroll(o/p)
              set $mode_workspaces (h) move workspace left, (l) move workspace right

              # Define i3status refresh command
              set $refresh_i3status killall -SIGUSR1 i3status
            '';
          };
        };
      };
      programs.i3status = {
        enable = true;
        general = {
          output_format = "i3bar";
          colors = true;
          interval = 5;
        };
        modules = {
          "ethernet eth0" = {
            position = 1;
            settings = {
              format_up = "E: %ip (%speed)";
              format_down = "E: down";
            };
          };
          "wireless wlan0" = {
            position = 2;
            settings = {
              format_up = "W: (%quality at %essid, %bitrate) %ip";
              format_down = "W: down";
            };
          };
          "disk /" = {
            position = 3;
            settings = {
              format = "%free";
            };
          };
          "battery 0" = {
            position = 4;
            settings = {
              format = "%status %percentage %remaining %emptytime";
              format_down = "";
              status_chr = "⚡";
              status_bat = "🔋";
              status_unk = "";
              status_full = "";
              path = "/sys/class/power_supply/BAT%d/uevent";
              low_threshold = 10;
            };
          };
          "memory" = {
            position = 5;
            settings = {
              format = "Tax Fraud Docs: %used";
              threshold_degraded = "10%";
              format_degraded = "COMMIT MORE TAX FRAUD: %free";
            };
          };
          "tztime local" = {
            position = 7;
            settings = {
              format = "%Y-%m-%d %H:%M:%S";
            };
          };
        };
      };
    };
}
