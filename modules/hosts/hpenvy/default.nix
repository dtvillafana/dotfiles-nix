{ self, inputs, ... }:
{
  flake.nixosConfigurations.hpenvynix = inputs.nixpkgs.lib.nixosSystem {
    modules = [
      inputs.determinate.nixosModules.default
      inputs.home-manager.nixosModules.home-manager
      inputs.sops-nix.nixosModules.sops
      self.nixosModules.common
      self.nixosModules.guestHome
      self.nixosModules.hpenvyConfig
      self.nixosModules.hpenvyHardware
      self.nixosModules.virHome
    ];
    specialArgs = {
      inherit (inputs)
        home-manager
        nixvim
        llm-agents
        ;
      nodename = "hpenvynix";
      system = "x86_64-linux";
    };
  };
}
