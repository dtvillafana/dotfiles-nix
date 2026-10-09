{ ... }:
{
  flake.nixosModules.hpXeonConfig =
    { config, ... }:
    {
      boot.loader.grub = {
        enable = true;
        device = "/dev/sda";
      };

      services.xserver.videoDrivers = [ "nvidia" ];

      hardware.nvidia = {
        package = config.boot.kernelPackages.nvidiaPackages.legacy_580;
        modesetting.enable = true;
        open = false;
      };

      hardware.graphics.enable = true;
      services.sheepit = {
        enable = true;
        memoryGiB = 8;
      };
    };
}
