{ self, inputs, ... }:
{
  flake.nixosConfigurations.rogdesktop = inputs.nixpkgs.lib.nixosSystem {
    modules = [
      inputs.determinate.nixosModules.default
      inputs.home-manager.nixosModules.home-manager
      inputs.sops-nix.nixosModules.sops
      self.nixosModules.common
      self.nixosModules.rogdesktopConfig
      self.nixosModules.rogdesktopHardware
      self.nixosModules.virHome
    ];
    specialArgs = {
      inherit (inputs)
        home-manager
        nixvim
        claude-code
        codex-cli
        opencode-tui
        ;
      nodename = "rogdesktop";
      system = "x86_64-linux";
    };
  };
}
