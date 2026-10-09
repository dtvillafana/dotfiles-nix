{ self, ... }:
{
  flake.homeModules.thinkpadMonitors =
    { lib, ... }:
    {
      imports = [ self.homeModules.monitors ];
      xdg.configFile."hypr/monitor-defaults.lua".text = lib.mkAfter ''
        hl.monitor({ output = "HDMI-A-1", mode = "2048x1152", position = "0x0", scale = 1 })
        hl.monitor({ output = "eDP-1", mode = "1920x1080", position = "2048x403", scale = 1 })
      '';
    };
  flake.nixosModules.thinkpadMonitors.home-manager.sharedModules = [
    self.homeModules.thinkpadMonitors
  ];
}
