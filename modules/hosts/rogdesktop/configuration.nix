{ self, inputs, ... }:
{
  flake.nixosModules.rogdesktopConfig =
    { config, ... }:
    let
      xsessionInitExtra = ''
        xset -dpms
        xset s off
        xset s noblank
      '';
    in
    {
      imports = [
        self.nixosModules.androidTools
        self.nixosModules.rogdesktopHardware
      ];

      services.xserver.videoDrivers = [ "nvidia" ];

      hardware.nvidia = {
        package = config.boot.kernelPackages.nvidiaPackages.legacy_580;
        modesetting.enable = true;
        open = false;
      };

      hardware.graphics.enable = true;

      programs.steam.enable = true;

      home-manager.users = builtins.listToAttrs (
        map
          (username: {
            name = username;
            value.xsession.initExtra = xsessionInitExtra;
          })
          [
            "vir"
            "capcu"
          ]
      );
    };
}
