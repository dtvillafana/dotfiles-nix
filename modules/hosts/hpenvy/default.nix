{ self, inputs, ... }:
let
  mkHpenvy =
    secretsEnabled:
    inputs.nixpkgs.lib.nixosSystem {
      modules = [
        inputs.determinate.nixosModules.default
        inputs.home-manager.nixosModules.home-manager
        inputs.sops-nix.nixosModules.sops
        self.nixosModules.common
        self.nixosModules.guestHome
        self.nixosModules.hpenvyConfig
        self.nixosModules.hpenvyHardware
        self.nixosModules.virHome
        self.nixosModules.capcuHome
      ];
      specialArgs = {
        inherit secretsEnabled;
        inherit (inputs)
          home-manager
          nixvim
          llm-agents
          ;
        nodename = "hpenvynix";
        system = "x86_64-linux";
      };
    };
in
{
  flake.nixosConfigurations = {
    hpenvynix = mkHpenvy true;
    hpenvynixBootstrap = mkHpenvy false;
  };
}
