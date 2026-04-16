{ self, inputs, ... }:
{
  flake.nixosConfigurations.thinkpad = inputs.nixpkgs.lib.nixosSystem {
    modules = [
      inputs.determinate.nixosModules.default
      inputs.home-manager.nixosModules.home-manager
      inputs.sops-nix.nixosModules.sops
      self.nixosModules.common
      self.nixosModules.thinkpadConfig
      self.nixosModules.thinkpadHardware
      self.nixosModules.virHome
    ];
    specialArgs = {
      inherit (inputs)
        home-manager
        nixvim
        llm-agents
        ;
      nodename = "thinkpad";
      system = "x86_64-linux";
    };
  };
}
