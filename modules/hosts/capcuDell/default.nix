{ self, inputs, ... }:
{
  flake.nixosConfigurations.capcuDell = inputs.nixpkgs.lib.nixosSystem {
    modules = [
      inputs.determinate.nixosModules.default
      inputs.home-manager.nixosModules.home-manager
      inputs.sops-nix.nixosModules.sops
      self.nixosModules.common
      self.nixosModules.capcuDellConfig
      self.nixosModules.capcuDellHardware
      self.nixosModules.capcuHome
    ];
    specialArgs = {
      inherit (inputs)
        home-manager
        nixvim
        llm-agents
        ;
      nodename = "capcuDell";
      system = "x86_64-linux";
    };
  };

  flake.nixosConfigurations.capcuDellBootstrap = inputs.nixpkgs.lib.nixosSystem {
    modules = [
      inputs.determinate.nixosModules.default
      self.nixosModules.bootstrapCommon
      self.nixosModules.capcuDellBootstrapConfig
      self.nixosModules.capcuDellHardware
    ];
    specialArgs = {
      nodename = "capcuDell";
      system = "x86_64-linux";
    };
  };
}
