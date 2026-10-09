{ self, inputs, ... }:
let
  mkThinkpad =
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
        self.nixosModules.lowBatteryDim
        self.nixosModules.thinkpadConfig
        self.nixosModules.thinkpadMonitors
        self.nixosModules.thinkpadHardware
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
        nodename = "thinkpad";
        system = "x86_64-linux";
      };
    };
in
{
  flake.nixosConfigurations = {
    thinkpad = mkThinkpad true;
    thinkpadBootstrap = mkThinkpad false;
  };
}
