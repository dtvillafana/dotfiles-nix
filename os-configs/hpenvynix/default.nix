{ pkgs, ... }:
{
  services.xserver.windowManager.i3 = {
    extraPackages = with pkgs; [
      # enable wifi drivers
      linuxKernel.packages.linux_6_6_hardened.broadcom_sta
    ];
  };
}
