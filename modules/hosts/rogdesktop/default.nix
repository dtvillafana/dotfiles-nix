{ self, inputs, ... }:
{
  flake.nixosConfigurations.rogdesktop = inputs.nixpkgs.lib.nixosSystem {
    modules = [
      inputs.determinate.nixosModules.default
      inputs.home-manager.nixosModules.home-manager
      inputs.hermes-agent.nixosModules.default
      inputs.hermes-webui.nixosModules.default
      inputs.sops-nix.nixosModules.sops
      self.nixosModules.common
      self.nixosModules.rogdesktopConfig
      self.nixosModules.rogdesktopHardware
      self.nixosModules.virHome
      self.nixosModules.capcuHome
      self.nixosModules.guestHome
      self.nixosModules.experiment
      self.nixosModules.ollama
    ];
    specialArgs = {
      inherit (inputs)
        hermes-agent
        home-manager
        nixvim
        llm-agents
        ;
      nodename = "rogdesktop";
      system = "x86_64-linux";
    };
  };
}
