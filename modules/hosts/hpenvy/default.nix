{ self, inputs, ... }:
{
  flake.nixosConfigurations.hpenvynix = inputs.nixpkgs.lib.nixosSystem {
    modules = [
      inputs.determinate.nixosModules.default
      inputs.home-manager.nixosModules.home-manager
      inputs.sops-nix.nixosModules.sops
      self.nixosModules.common
      self.nixosModules.virHome
      self.nixosModules.tmux
      self.nixosModules.hpenvyHardware
      self.nixosModules.hpenvyConfig
      self.nixosModules.guestHome
    ];
    specialArgs = {
      inherit (inputs)
        home-manager
        nixvim
        claude-code
        codex-cli
        opencode-tui
        ;
      nodename = "hpenvynix";
      system = "x86_64-linux";
    };
  };
}
