{ ... }:
{
  flake.homeModules.monitors =
    {
      config,
      lib,
      ...
    }:
    {
      # Hyprland applies these rules on hotplug; unknown outputs stay enabled.
      # Confirm dock connector names with `hyprctl monitors all` after migration.
      xdg.configFile."hypr/monitor-defaults.lua".text = ''
        hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 })
      '';

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
