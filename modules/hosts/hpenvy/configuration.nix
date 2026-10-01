{ ... }:
{
  flake.nixosModules.hpenvyConfig =
    {
      pkgs,
      ...
    }:
    {
      environment.systemPackages = with pkgs; [
        linuxKernel.packages.linux_hardened.broadcom_sta
      ];

    };
}
