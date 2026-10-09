{ self, ... }:
{
  flake.homeModules.capcuDellMonitors =
    { lib, ... }:
    {
      imports = [ self.homeModules.monitors ];
      xdg.configFile."hypr/monitor-defaults.lua".text = lib.mkAfter ''
        hl.monitor({ output = "DP-2", mode = "1920x1080@60", position = "0x672", scale = 1 })
        hl.monitor({ output = "HDMI-A-1", mode = "1920x1080@60", position = "1920x0", scale = 1, transform = 1 })
        hl.monitor({ output = "DP-1-7", mode = "1920x1080@60", position = "3000x672", scale = 1 })
      '';
    };
  flake.nixosModules.capcuDellDesktop = {
    home-manager.sharedModules = [ self.homeModules.capcuDellMonitors ];
    # Preserve capcu's existing SSH-tunnel endpoint and greeter handoff.
    home-manager.users.capcu.xdg.configFile."wayvnc/config".text = ''
      address=127.0.0.1 ::1
      port=5901
      enable_auth=false
    '';
  };
}
