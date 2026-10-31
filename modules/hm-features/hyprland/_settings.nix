# Private Home Manager module: excluded from the flake's recursive import-tree.
{ lib, ... }:
let
  lua = lib.generators.mkLuaInline;
  bind = key: description: action: {
    _args = [
      key
      (lua action)
      {
        inherit description;
      }
    ];
  };
  exec = key: command: flags: {
    _args = [
      key
      (lua "hl.dsp.exec_cmd(${lib.generators.toLua { } command})")
      flags
    ];
  };
  resetBinds = map (key: bind key "Exit mode" "hl.dsp.submap('reset')") [
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
      class = "(org\\.pwmt\\.zathura|[Zz]athura|libreoffice.*|kolourpaint|[Ss]office)";
    }
    {
      name = "media";
      class = "(vlc|org\\.videolan\\.VLC)";
    }
    {
      name = "comms";
      class = "([Ss]ignal|org\\.signal\\.Signal|TelegramDesktop|org\\.telegram\\.desktop|com\\.ayugram\\.desktop|Microsoft Teams - Preview|teams-for-linux)";
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
                description =
                  if entry.x < 0 then
                    "Make window narrower"
                  else if entry.x > 0 then
                    "Make window wider"
                  else if entry.y < 0 then
                    "Make window shorter"
                  else
                    "Make window taller";
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
        ++ [ (bind "SUPER + R" "Exit resize mode" "hl.dsp.submap('reset')") ];
      bar.settings.bind = [
        (exec "H" "pkill -SIGUSR1 -x waybar" { description = "Hide status bar"; })
        (exec "SHIFT + H" "pkill -SIGUSR2 -x waybar" { description = "Show status bar"; })
      ]
      ++ resetBinds;
      workspaces.settings.bind = [
        (bind "H" "Move workspace to left monitor" "hl.dsp.workspace.move({ monitor = 'l' })")
        (bind "L" "Move workspace to right monitor" "hl.dsp.workspace.move({ monitor = 'r' })")
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
          zoom_detached_camera = false;
          zoom_rigid = true;
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
              (bind "SUPER + ${key}" "Switch to ${workspace.name} workspace"
                "hl.dsp.focus({ workspace = ${target} })"
              )
              (bind "SUPER + SHIFT + ${key}" "Move window to ${workspace.name} workspace"
                "hl.dsp.window.move({ workspace = ${target}, follow = false })"
              )
            ]
          ) workspaces
        )
        ++ [
          (exec "Super_L" "hypr-desktop-action bindings show-held" {
            description = "Show keyboard shortcuts";
            long_press = true;
            non_consuming = true;
          })
          (exec "Super_R" "hypr-desktop-action bindings show-held" {
            description = "Show keyboard shortcuts";
            long_press = true;
            non_consuming = true;
          })
          (exec "Super_L" "hypr-desktop-action bindings hide-held" {
            description = "Hide keyboard shortcuts";
            release = true;
            ignore_mods = true;
            non_consuming = true;
            transparent = true;
            submap_universal = true;
          })
          (exec "Super_R" "hypr-desktop-action bindings hide-held" {
            description = "Hide keyboard shortcuts";
            release = true;
            ignore_mods = true;
            non_consuming = true;
            transparent = true;
            submap_universal = true;
          })
          (exec "SUPER + F1" "hypr-desktop-action bindings" { description = "Toggle bindings help"; })
          (exec "SUPER + Return" "ghostty" { description = "Open terminal"; })
          (exec "SUPER + SHIFT + Return" "hypr-neovide" { description = "Open text editor"; })
          (exec "SUPER + D" "hypr-desktop-action apps" { description = "Launch application"; })
          (exec "SUPER + SHIFT + D" "hypr-desktop-action run" { description = "Run command/Open Application"; })
          (exec "SUPER + SHIFT + W" "hypr-desktop-action workspaces ${
            lib.escapeShellArgs (map (workspace: workspace.name) workspaces)
          }" { description = "Switch workspace"; })
          (exec "SUPER + T" "hypr-desktop-action kill-user" { description = "Stop a process"; })
          (exec "SUPER + SHIFT + T" "hypr-desktop-action kill-root" {
            description = "Stop a process as administrator";
          })
          (exec "SUPER + G" "hypr-desktop-action password" { description = "Type saved password"; })
          (exec "SUPER + U" "hypr-desktop-action username" { description = "Type saved username"; })
          (exec "SUPER + O" "hypr-desktop-action otp" { description = "Type one-time password"; })
          (exec "SUPER + SHIFT + S" "hypr-desktop-action screenshot" {
            description = "Copy screenshot of selected area";
            release = true;
          })
          (exec "SUPER + ALT + S" "hypr-desktop-action ocr" {
            description = "Copy text from selected area";
            release = true;
          })
          (exec "SUPER + minus" "brightnessctl set 5%-" {
            description = "Decrease screen brightness";
            repeating = true;
          })
          # Use the unshifted keysym: '+' is Shift+'=' on the US laptop keyboard.
          (exec "SUPER + equal" "brightnessctl set +5%" {
            description = "Increase screen brightness";
            repeating = true;
          })
          (exec "SUPER + SHIFT + equal" "brightnessctl set +5%" {
            description = "Increase screen brightness";
            repeating = true;
          })
          (exec "SUPER + SHIFT + E" "hypr-desktop-action logout" { description = "Log out"; })
          (bind "SUPER + SHIFT + Q" "Close window" "hl.dsp.window.close()")
          (bind "SUPER + F" "Toggle fullscreen" "hl.dsp.window.fullscreen()")
          (bind "SUPER + SHIFT + space" "Toggle floating window" "hl.dsp.window.float()")
          (bind "SUPER + space" "Cycle windows" "hl.dsp.window.cycle_next()")
          (bind "SUPER + Tab" "Next window in group" "hl.dsp.group.next()")
          (bind "SUPER + SHIFT + Tab" "Previous window in group" "hl.dsp.group.prev()")
          (exec "SUPER + SHIFT + C" "hyprctl reload" { description = "Reload desktop configuration"; })
          (exec "SUPER + SHIFT + R" "hyprctl reload" { description = "Reload desktop configuration"; })
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
          (exec "SUPER + P" "hypr-desktop-action touchpad-off" { description = "Disable touchpad"; })
          (exec "SUPER + SHIFT + P" "hypr-desktop-action touchpad-on" { description = "Enable touchpad"; })
          (exec "XF86AudioRaiseVolume" "wpctl set-volume @DEFAULT_AUDIO_SINK@ 10%+" {
            description = "Increase volume";
            locked = true;
            repeating = true;
          })
          (exec "XF86AudioLowerVolume" "wpctl set-volume @DEFAULT_AUDIO_SINK@ 10%-" {
            description = "Decrease volume";
            locked = true;
            repeating = true;
          })
          (exec "XF86AudioMute" "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle" {
            description = "Toggle speaker mute";
            locked = true;
          })
          (exec "XF86AudioMicMute" "wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle" {
            description = "Toggle microphone mute";
            locked = true;
          })
          (exec "SUPER + BackSpace" "hypr-desktop-action palette" {
            description = "Open power and session menu";
          })
          (bind "SUPER + R" "Resize window mode" "hl.dsp.submap('resize')")
          (bind "SUPER + I" "Status bar mode" "hl.dsp.submap('bar')")
          (bind "SUPER + M" "Move workspace mode" "hl.dsp.submap('workspaces')")
          (bind "SUPER + C" "Mouse control mode" "hl.dsp.submap('mouse')")
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
