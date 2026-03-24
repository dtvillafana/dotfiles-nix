{ self, ... }:
{
  flake.nixosModules.rogdesktopConfig =
    { ... }:
    {
      imports = [
        self.nixosModules.rogdesktopHardware
      ];

      services.xserver.videoDrivers = [ "nvidia" ];

      users.users.vir.extraGroups = [
        "adbusers"
      ];
      users.groups.adbusers = { };

      hardware.nvidia = {
        modesetting.enable = true;
        open = false;
      };

      hardware.graphics.enable = true;

      home-manager.users.vir =
        { pkgs, ... }:
        {
          home.packages = with pkgs; [
            android-tools
          ];
          xsession.initExtra = ''
            xset -dpms
            xset s off
            xset s noblank
          '';
        };
    };
}
