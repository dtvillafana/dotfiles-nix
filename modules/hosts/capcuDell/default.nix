{ self, inputs, ... }:
{
  flake.nixosConfigurations.capcuDellBootstrap = inputs.nixpkgs.lib.nixosSystem {
    modules = [
      inputs.determinate.nixosModules.default
      self.nixosModules.bootstrapCommon
      self.nixosModules.capcuDellBootstrapConfig
      self.nixosModules.capcuDellBootstrapHardware
    ];
    specialArgs = {
      nodename = "capcuDell";
      system = "x86_64-linux";
    };
  };
}
