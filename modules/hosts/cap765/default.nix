{ self, inputs, ... }:
{
  flake.nixosConfigurations.cap765 = inputs.nixpkgs.lib.nixosSystem {
    modules = [
      inputs.determinate.nixosModules.default
      inputs.home-manager.nixosModules.home-manager
      inputs.sops-nix.nixosModules.sops
      self.nixosModules.common
      self.nixosModules.cap765Hardware
      self.nixosModules.capcuHome
    ];
    specialArgs = {
      inherit (inputs)
        home-manager
        nixvim
        llm-agents
        ;
      nodename = "cap765";
      system = "x86_64-linux";
    };
  };
}
