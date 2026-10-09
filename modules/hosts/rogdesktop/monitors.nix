{ self, ... }:
{
  flake.homeModules.rogdesktopMonitors =
    { lib, ... }:
    {
      imports = [ self.homeModules.monitors ];
      xdg.configFile."hypr/monitor-defaults.lua".text = lib.mkAfter ''
        hl.monitor({ output = "HDMI-A-1", mode = "3440x1440@100", position = "0x0", scale = 1 })
      '';
    };
  flake.nixosModules.rogdesktopMonitors.home-manager.sharedModules = [
    self.homeModules.rogdesktopMonitors
  ];
}
