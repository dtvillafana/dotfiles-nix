{ self, inputs, ... }:
{
  flake.nixosModules.rogdesktopConfig =
    { config, ... }:
    {
      imports = [
        self.nixosModules.rogdesktopHardware
      ];

      services.xserver.videoDrivers = [ "nvidia" ];

      users.users.vir.extraGroups = [ "adbusers" ];
      users.users.capcu.extraGroups = [ "adbusers" ];
      users.groups.adbusers = { };

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
            value =
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
          })
          [
            "vir"
            "capcu"
          ]
      );
    };
}
