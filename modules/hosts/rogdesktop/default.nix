{ self, inputs, ... }:
let
  mkRogdesktop =
    secretsEnabled:
    inputs.nixpkgs.lib.nixosSystem {
      modules = [
        inputs.determinate.nixosModules.default
        inputs.home-manager.nixosModules.home-manager
        self.nixosModules.hermesRogdesktop
        inputs.sops-nix.nixosModules.sops
        self.nixosModules.baseSystem
        self.nixosModules.nixPolicy
        self.nixosModules.systemSecrets
        self.nixosModules.headscale
        self.nixosModules.desktopServices
        self.nixosModules.office
        self.nixosModules.printing3d
        self.nixosModules.rogdesktopConfig
        self.nixosModules.rogdesktopMonitors
        self.nixosModules.rogdesktopHardware
        self.nixosModules.virHome
        self.nixosModules.blender
        self.nixosModules.capcuHome
        self.nixosModules.guestHome
        self.nixosModules.experiment
        self.nixosModules.localModelsPascal
        self.nixosModules.sheepit
      ];
      specialArgs = {
        inherit secretsEnabled;
        inherit (inputs)
          home-manager
          nixvim
          llm-agents
          ;
        nodename = "rogdesktop";
        system = "x86_64-linux";
      };
    };
in
{
  flake.nixosConfigurations = {
    rogdesktop = mkRogdesktop true;
    rogdesktopBootstrap = mkRogdesktop false;
  };
}
