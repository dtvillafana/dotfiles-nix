{ self, inputs, ... }:
let
  mkHpXeon =
    secretsEnabled:
    inputs.nixpkgs.lib.nixosSystem {
      modules = [
        inputs.determinate.nixosModules.default
        inputs.home-manager.nixosModules.home-manager
        inputs.sops-nix.nixosModules.sops
        self.nixosModules.baseSystem
        self.nixosModules.nixPolicy
        self.nixosModules.systemSecrets
        self.nixosModules.headscale
        self.nixosModules.desktopServices
        self.nixosModules.office
        self.nixosModules.hpXeonConfig
        self.nixosModules.hpXeonHardware
        self.nixosModules.virHome
        self.nixosModules.guestHome
      ];
      specialArgs = {
        inherit secretsEnabled;
        inherit (inputs)
          home-manager
          nixvim
          llm-agents
          ;
        nodename = "hp-xeon";
        system = "x86_64-linux";
      };
    };
in
{
  flake.nixosConfigurations = {
    hp-xeon = mkHpXeon true;
    hp-xeonBootstrap = mkHpXeon false;
  };
}
