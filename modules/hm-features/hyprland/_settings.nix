# Private Home Manager module: excluded from the flake's recursive import-tree.
{ lib, ... }:
let
  lua = lib.generators.mkLuaInline;
  bind = key: action: {
    _args = [
      key
      (lua action)
      {
        description =
          {
            "hl.dsp.submap('reset')" = "Exit mode";
            "hl.dsp.submap('resize')" = "Resize mode";
            "hl.dsp.submap('bar')" = "Bar mode";
            "hl.dsp.submap('workspaces')" = "Workspace mode";
            "hl.dsp.submap('mouse')" = "Mouse mode";
            "hl.dsp.window.close()" = "Close window";
            "hl.dsp.window.fullscreen()" = "Toggle fullscreen";
            "hl.dsp.window.float()" = "Toggle floating";
            "hl.dsp.window.cycle_next()" = "Cycle windows";
            "hl.dsp.focus({ last = true })" = "Focus previous window";
            "hl.dsp.layout('preselect r')" = "Preselect split right";
            "hl.dsp.layout('preselect d')" = "Preselect split down";
            "hl.dsp.group.next()" = "Next group window";
            "hl.dsp.group.prev()" = "Previous group window";
            "hl.dsp.workspace.move({ monitor = 'l' })" = "Move workspace to left monitor";
            "hl.dsp.workspace.move({ monitor = 'r' })" = "Move workspace to right monitor";
          }
          .${action} or (lib.removePrefix "hl.dsp." action);
      }
    ];
  };
  exec = key: command: flags: {
    _args = [
      key
      (lua "hl.dsp.exec_cmd(${lib.generators.toLua { } command})")
      ({ description = command; } // flags)
    ];
  };
  resetBinds = map (key: bind key "hl.dsp.submap('reset')") [
    "Escape"
    "Return"
  ];
  workspaces = [
    {
      name = "terminals";
      class = "(org\\.wezfurlong\\.wezterm|wezterm|ghostty|com\\.mitchellh\\.ghostty)";
    }
    {
      name = "web";
      class = "(qutebrowser|[Bb]rave-browser|[Cc]hromium(-browser)?|firefox|org\\.mozilla\\.firefox)";
    }
    {
      name = "documents";
      class = "(org\\.pwmt\\.zathura|[Zz]athura|libreoffice.*|kolourpaint|[Ss]office|ONLYOFFICE|DesktopEditors)";
    }
    {
      name = "media";
      class = "(vlc|org\\.videolan\\.VLC)";
    }
    {
      name = "comms";
      class = "([Ss]ignal|org\\.signal\\.Signal|TelegramDesktop|org\\.telegram\\.desktop|Microsoft Teams - Preview|teams-for-linux)";
    }
    {
      name = "VMs";
      class = "(\\.virt-manager-wrapped|virt-manager|steam)";
    }
    {
      name = "DB";
      class = "(sqlitebrowser|DB Browser for SQLite)";
    }
    {
      name = "SSH";
      class = "org\\.remmina\\.Remmina";
    }
    {
      name = "misc";
      class = "(pavucontrol|org\\.pulseaudio\\.pavucontrol|wdisplays)";
    }
    { name = "Background Processes"; }
  ];
in
{
  wayland.windowManager.hyprland = {
    enable = true;
    package = null; # NixOS installs the compositor.
    portalPackage = null; # NixOS owns the compositor and portals.
    configType = "lua";
    systemd.enable = false; # UWSM owns graphical-session.target.
    extraConfig = builtins.readFile ./config.lua;
    submaps = {
      resize.settings.bind =
        map
          (entry: {
            _args = [
              entry.key
              (lua "hl.dsp.window.resize({ x = ${toString entry.x}, y = ${toString entry.y}, relative = true })")
              {
                repeating = true;
                description = "Resize window by ${toString entry.x}, ${toString entry.y}";
              }
            ];
          })
          [
            {
              key = "H";
              x = -10;
              y = 0;
            }
            {
              key = "J";
              x = 0;
              y = 10;
            }
            {
              key = "K";
              x = 0;
              y = -10;
            }
            {
              key = "L";
              x = 10;
              y = 0;
            }
            {
              key = "Left";
              x = -10;
              y = 0;
            }
            {
              key = "Down";
              x = 0;
              y = 10;
            }
            {
              key = "Up";
              x = 0;
              y = -10;
            }
            {
              key = "Right";
              x = 10;
              y = 0;
            }
          ]
        ++ resetBinds
        ++ [ (bind "SUPER + R" "hl.dsp.submap('reset')") ];
      bar.settings.bind = [
        (exec "H" "pkill -SIGUSR1 -x waybar" { })
        (exec "SHIFT + H" "pkill -SIGUSR2 -x waybar" { })
      ]
      ++ resetBinds;
      workspaces.settings.bind = [
        (bind "H" "hl.dsp.workspace.move({ monitor = 'l' })")
        (bind "L" "hl.dsp.workspace.move({ monitor = 'r' })")
      ]
      ++ resetBinds;
    };
    settings = {
      env = [
        {
          _args = [
            "NIXOS_OZONE_WL"
            "1"
          ];
        }
        {
          _args = [
            "XCURSOR_THEME"
            "Adwaita"
          ];
        }
        {
          _args = [
            "XCURSOR_SIZE"
            "24"
          ];
        }
      ];
      config = {
        ecosystem.no_update_news = true;
        general = {
          layout = "dwindle";
          gaps_in = 0;
          gaps_out = 0;
          border_size = 0;
        };
        decoration = {
          rounding = 0;
          blur.enabled = false;
          shadow.enabled = false;
        };
        animations.enabled = false;
        input = {
          kb_layout = "us";
          kb_options = "ctrl:swapcaps";
          # Hyprland's native long-press bindings use the keyboard repeat delay.
          repeat_delay = 1000;
          follow_mouse = 1;
        };
        cursor = {
          no_warps = true;
          enable_hyprcursor = false;
        };
        dwindle.preserve_split = true;
        binds.workspace_back_and_forth = true;
        misc = {
          disable_hyprland_logo = true;
          disable_splash_rendering = true;
          force_default_wallpaper = -1;
        };
      };
      bind =
        lib.concatLists (
          lib.imap1 (
            i: workspace:
            let
              target = lib.generators.toLua { } "name:${workspace.name}";
              key = toString (lib.mod i 10);
            in
            [
              (bind "SUPER + ${key}" "hl.dsp.focus({ workspace = ${target} })")
              (bind "SUPER + SHIFT + ${key}" "hl.dsp.window.move({ workspace = ${target}, follow = false })")
            ]
          ) workspaces
        )
        ++ [
          (exec "Super_L" "hypr-desktop-action bindings show-held" {
            long_press = true;
            non_consuming = true;
          })
          (exec "Super_R" "hypr-desktop-action bindings show-held" {
            long_press = true;
            non_consuming = true;
          })
          (exec "Super_L" "hypr-desktop-action bindings hide-held" {
            release = true;
            ignore_mods = true;
            non_consuming = true;
            transparent = true;
            submap_universal = true;
          })
          (exec "Super_R" "hypr-desktop-action bindings hide-held" {
            release = true;
            ignore_mods = true;
            non_consuming = true;
            transparent = true;
            submap_universal = true;
          })
          (exec "SUPER + F1" "hypr-desktop-action bindings" { description = "Toggle bindings help"; })
          (exec "SUPER + Return" "ghostty" { })
          (exec "SUPER + SHIFT + Return" "hypr-neovide" { })
          (exec "SUPER + D" "fuzzel" { })
          (exec "SUPER + SHIFT + D" "hypr-desktop-action run" { })
          (exec "SUPER + T" "hypr-desktop-action kill-user" { })
          (exec "SUPER + SHIFT + T" "hypr-desktop-action kill-root" { })
          (exec "SUPER + G" "hypr-desktop-action password" { })
          (exec "SUPER + U" "hypr-desktop-action username" { })
          (exec "SUPER + O" "hypr-desktop-action otp" { })
          (exec "SUPER + SHIFT + S" "hypr-desktop-action screenshot" { release = true; })
          (exec "SUPER + ALT + S" "hypr-desktop-action ocr" { release = true; })
          (exec "SUPER + minus" "brightnessctl set 5%-" { repeating = true; })
          (exec "SUPER + plus" "brightnessctl set +5%" { repeating = true; })
          (exec "SUPER + SHIFT + E" "hypr-desktop-action logout" { })
          (bind "SUPER + SHIFT + Q" "hl.dsp.window.close()")
          (bind "SUPER + F" "hl.dsp.window.fullscreen()")
          (bind "SUPER + SHIFT + space" "hl.dsp.window.float()")
          (bind "SUPER + space" "hl.dsp.window.cycle_next()")
          (bind "SUPER + A" "hl.dsp.focus({ last = true })")
          (bind "SUPER + B" "hl.dsp.layout('preselect r')")
          (bind "SUPER + V" "hl.dsp.layout('preselect d')")
          (bind "SUPER + Tab" "hl.dsp.group.next()")
          (bind "SUPER + SHIFT + Tab" "hl.dsp.group.prev()")
          (exec "SUPER + SHIFT + C" "hyprctl reload" { })
          (exec "SUPER + SHIFT + R" "hyprctl reload" { })
          {
            _args = [
              "SUPER + mouse:272"
              (lua "hl.dsp.window.drag()")
              {
                mouse = true;
                description = "Drag window";
              }
            ];
          }
          {
            _args = [
              "SUPER + mouse:273"
              (lua "hl.dsp.window.resize()")
              {
                mouse = true;
                description = "Resize window with mouse";
              }
            ];
          }
          (exec "SUPER + P" "hypr-desktop-action touchpad-off" { })
          (exec "SUPER + SHIFT + P" "hypr-desktop-action touchpad-on" { })
          (exec "XF86AudioRaiseVolume" "wpctl set-volume @DEFAULT_AUDIO_SINK@ 10%+" {
            locked = true;
            repeating = true;
          })
          (exec "XF86AudioLowerVolume" "wpctl set-volume @DEFAULT_AUDIO_SINK@ 10%-" {
            locked = true;
            repeating = true;
          })
          (exec "XF86AudioMute" "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle" { locked = true; })
          (exec "XF86AudioMicMute" "wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle" { locked = true; })
          (exec "SUPER + BackSpace" "hypr-desktop-action palette" { })
          (bind "SUPER + R" "hl.dsp.submap('resize')")
          (bind "SUPER + I" "hl.dsp.submap('bar')")
          (bind "SUPER + M" "hl.dsp.submap('workspaces')")
          (bind "SUPER + C" "hl.dsp.submap('mouse')")
        ];
      window_rule =
        map (workspace: {
          match.class = workspace.class;
          workspace = "name:${workspace.name} silent";
        }) (lib.filter (workspace: workspace ? class) workspaces)
        ++ [
          {
            # Keep hidden browsers rendering for individual-window PipeWire capture.
            name = "browser-background-rendering";
            match.class = (builtins.elemAt workspaces 1).class;
            render_unfocused = true;
          }
        ];
    };
  };
}
