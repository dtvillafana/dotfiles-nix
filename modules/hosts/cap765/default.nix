{ self, inputs, ... }:
let
  mkCap765 =
    secretsEnabled:
    inputs.nixpkgs.lib.nixosSystem {
      modules = [
        inputs.determinate.nixosModules.default
        inputs.home-manager.nixosModules.home-manager
        inputs.sops-nix.nixosModules.sops
        self.nixosModules.common
        self.nixosModules.cap765Hardware
        self.nixosModules.capcuHome
      ];
      specialArgs = {
        inherit secretsEnabled;
        inherit (inputs)
          home-manager
          nixvim
          llm-agents
          ;
        nodename = "cap765";
        system = "x86_64-linux";
      };
    };
in
{
  flake.nixosConfigurations = {
    cap765 = mkCap765 true;
    cap765Bootstrap = mkCap765 false;
  };
}
