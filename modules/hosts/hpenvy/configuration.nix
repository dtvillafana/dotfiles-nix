{ self, inputs, ... }:
{
  flake.nixosModules.hpenvyConfig =
    {
      pkgs,
      ...
    }:
    {
      services.xserver.windowManager.i3 = {
        extraPackages = with pkgs; [
          linuxKernel.packages.linux_hardened.broadcom_sta
        ];
      };

      services.desktopManager.plasma6.enable = true;
    };
}
