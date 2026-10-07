{ ... }:
{
  flake.homeModules.monitors =
    {
      osConfig,
      config,
      lib,
      ...
    }:
    {
      # Hyprland applies these rules on hotplug; unknown outputs stay enabled.
      # Confirm dock connector names with `hyprctl monitors all` after migration.
      xdg.configFile."hypr/monitor-defaults.lua".text = ''
        hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 })
      ''
      + (
        if osConfig.networking.hostName == "rogdesktop" then
          ''
            hl.monitor({ output = "HDMI-A-1", mode = "3440x1440@100", position = "0x0", scale = 1 })
          ''
        else if osConfig.networking.hostName == "thinkpad" then
          ''
            hl.monitor({ output = "HDMI-A-1", mode = "2048x1152", position = "0x0", scale = 1 })
            hl.monitor({ output = "eDP-1", mode = "1920x1080", position = "2048x403", scale = 1 })
          ''
        else if osConfig.networking.hostName == "capcuDell" then
          ''
            hl.monitor({ output = "DP-2", mode = "1920x1080@60", position = "0x672", scale = 1 })
            hl.monitor({ output = "HDMI-A-1", mode = "1920x1080@60", position = "1920x0", scale = 1, transform = 1 })
            hl.monitor({ output = "DP-1-7", mode = "1920x1080@60", position = "3000x672", scale = 1 })
          ''
        else
          ""
      );

      xdg.configFile."hypr/hyprmon-config-default.lua".text = ''
        require("hyprmon")
      '';

      # Preserve the old layout; HyprMon owns subsequent changes to its sidecar.
      # Its writable entrypoint keeps saves away from Home Manager's configuration.
      home.activation.initializeHyprlandMonitors = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
        if [ ! -e ${lib.escapeShellArg "${config.xdg.configHome}/hypr/hyprmon.lua"} ]; then
          if [ -e ${lib.escapeShellArg "${config.xdg.configHome}/hypr/monitors.lua"} ]; then
            run cp ${lib.escapeShellArg "${config.xdg.configHome}/hypr/monitors.lua"} ${lib.escapeShellArg "${config.xdg.configHome}/hypr/hyprmon.lua"}
          else
            run cp ${lib.escapeShellArg "${config.xdg.configHome}/hypr/monitor-defaults.lua"} ${lib.escapeShellArg "${config.xdg.configHome}/hypr/hyprmon.lua"}
          fi
          run chmod u+w ${lib.escapeShellArg "${config.xdg.configHome}/hypr/hyprmon.lua"}
        fi
        if [ ! -e ${lib.escapeShellArg "${config.xdg.configHome}/hypr/hyprmon-config.lua"} ]; then
          run cp ${lib.escapeShellArg "${config.xdg.configHome}/hypr/hyprmon-config-default.lua"} ${lib.escapeShellArg "${config.xdg.configHome}/hypr/hyprmon-config.lua"}
          run chmod u+w ${lib.escapeShellArg "${config.xdg.configHome}/hypr/hyprmon-config.lua"}
        fi
      '';
    };
}
