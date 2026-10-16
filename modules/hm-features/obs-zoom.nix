{ self, ... }:
{
  flake.homeModules.obs-zoom =
    { lib, pkgs, ... }:
    let
      bridge = pkgs.writeShellApplication {
        name = "obs-hyprland-zoom";
        runtimeInputs = [ pkgs.python3 ];
        text = ''
          exec python3 ${./obs-zoom/bridge.py} "$@"
        '';
      };
    in
    {
      imports = [ self.homeModules.hyprland ];

      programs.obs-studio.enable = true;
      home.packages = [ bridge ];
      xdg.configFile."obs-studio/scripts/hyprland-zoom.lua".source = ./obs-zoom/zoom.lua;
      xdg.configFile."obs-studio/scripts/hyprland-zoom.md".source = ./obs-zoom/README.md;

      systemd.user.services.obs-hyprland-zoom = {
        Unit = {
          Description = "Hyprland cursor and window geometry for OBS zoom";
          After = [ "graphical-session.target" ];
          PartOf = [ "graphical-session.target" ];
        };
        Service = {
          ExecStart = "${lib.getExe bridge}";
          Restart = "on-failure";
          RestartSec = 2;
          UMask = "0077";
        };
        Install.WantedBy = [ "graphical-session.target" ];
      };

      wayland.windowManager.hyprland.settings.bind = [
        {
          _args = [
            "SUPER + SHIFT + Z"
            (lib.generators.mkLuaInline "hl.dsp.exec_cmd(${
              lib.generators.toLua { } "${lib.getExe bridge} --toggle"
            })")
            { description = "Toggle OBS mouse-follow zoom on the active window"; }
          ];
        }
      ];
    };
}
