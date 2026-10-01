{ ... }:
{
  flake.nixosModules.hpenvyConfig =
    {
      config,
      ...
    }:
    {
      environment.systemPackages = [
        config.boot.kernelPackages.broadcom_sta
      ];

    };
}
