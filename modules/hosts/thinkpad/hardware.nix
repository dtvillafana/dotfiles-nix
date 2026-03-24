{ self, inputs, ... }:
{
  flake.nixosModules.thinkpadHardware =
    {
      config,
      lib,
      modulesPath,
      ...
    }:
    {
      imports = [
        (modulesPath + "/installer/scan/not-detected.nix")
      ];

      boot.initrd.availableKernelModules = [
        "xhci_pci"
        "ahci"
        "usb_storage"
        "sd_mod"
        "sr_mod"
        "sdhci_pci"
      ];
      boot.initrd.kernelModules = [ ];
      boot.kernelModules = [ ];
      boot.extraModulePackages = [ ];
      hardware.enableAllFirmware = true;
      boot.loader.systemd-boot.enable = false;
      boot.loader.grub = {
        enable = true;
        device = "/dev/nvme0n1";
        configurationLimit = 10;
      };
      boot.loader.efi.canTouchEfiVariables = false;

      fileSystems."/" = {
        device = "/dev/disk/by-uuid/4e2d05a9-b123-4456-bc61-8ec2bd7b9f62";
        fsType = "ext4";
      };

      swapDevices = [ ];

      networking.useDHCP = lib.mkDefault true;

      nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
      hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
    };
}
