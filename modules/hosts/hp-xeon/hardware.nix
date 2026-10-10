{ ... }:
{
  flake.nixosModules.hpXeonHardware =
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
        "uhci_hcd"
        "ehci_pci"
        "ahci"
        "xhci_pci"
        "firewire_ohci"
        "usb_storage"
        "usbhid"
        "sd_mod"
        "sr_mod"
      ];
      boot.initrd.kernelModules = [ ];
      boot.kernelModules = [ "kvm-intel" ];
      boot.extraModulePackages = [ ];

      fileSystems."/" = {
        device = "/dev/disk/by-uuid/a78070df-7e21-4b21-8b6e-a2cf8d27dad5";
        fsType = "ext4";
        options = [ "noatime" ];
      };

      fileSystems."/mnt/storage" = {
        device = "/dev/disk/by-uuid/fbfd3e08-ae46-4a04-9da6-a01affe34958";
        fsType = "ext4";
        options = [
          "nofail"
          "noatime"
          "x-systemd.automount"
        ];
      };

      swapDevices = [ ];

      networking.useDHCP = lib.mkDefault true;

      nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
      hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
    };
}
