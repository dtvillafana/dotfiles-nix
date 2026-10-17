{ ... }:
{
  flake.nixosModules.hpXeonConfig =
    { config, ... }:
    {
      boot.loader.grub = {
        enable = true;
        device = "/dev/disk/by-id/ata-Samsung_SSD_840_EVO_250GB_S1DBNSAFA40140X";
      };

      services.fstrim.enable = true;

      powerManagement.cpuFreqGovernor = "performance";

      services.xserver.videoDrivers = [ "nvidia" ];

      hardware.nvidia = {
        package = config.boot.kernelPackages.nvidiaPackages.legacy_580;
        modesetting.enable = true;
        open = false;
      };

      hardware.graphics.enable = true;
      services.sheepit = {
        memoryGiB = 8;
        # The connected controller continuously emits absolute-axis events at rest.
        ignoredInputDevices = [
          "Sony Interactive Entertainment Wireless Controller"
          "Sony Interactive Entertainment Wireless Controller Touchpad"
        ];
      };
    };
}
