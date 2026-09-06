{ self, inputs, ... }:
let
  mkCapcuDell =
    secretsEnabled:
    inputs.nixpkgs.lib.nixosSystem {
      modules = [
        inputs.determinate.nixosModules.default
        inputs.hermes-agent.nixosModules.default
        inputs.hermes-webui.nixosModules.default
        inputs.home-manager.nixosModules.home-manager
        inputs.sops-nix.nixosModules.sops
        self.nixosModules.common
        self.nixosModules.capcuDellConfig
        self.nixosModules.capcuDellHardware
        self.nixosModules.capcuHome
        self.nixosModules.ollama
      ];
      specialArgs = {
        inherit secretsEnabled;
        inherit (inputs)
          hermes-agent
          home-manager
          nixvim
          llm-agents
          ;
        nodename = "capcuDell";
        system = "x86_64-linux";
      };
    };
in
{
  flake.nixosConfigurations = {
    capcuDell = mkCapcuDell true;
    capcuDellBootstrap = mkCapcuDell false;
  };
}
