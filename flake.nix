{
  description = "NixOS configurations for David";
  inputs = {
    determinate.url = "https://flakehub.com/f/DeterminateSystems/determinate/0.1";
    # Use Determinate's weekly nixpkgs which tracks nixos-unstable
    # nixpkgs.url = "https://flakehub.com/f/DeterminateSystems/nixpkgs-weekly/0.1";
    nixpkgs.url = "https://flakehub.com/f/NixOS/nixpkgs/0.2505.0";
    # Use the matching release branch of home-manager for your nixpkgs version
    home-manager = {
      url = "github:nix-community/home-manager/release-25.05";
      # This ensures home-manager uses the same nixpkgs as my system
      inputs.nixpkgs.follows = "nixpkgs";
    };
    claude-code.url = "github:sadjow/claude-code-nix";
    opencode-tui.url = "github:aodhanhayter/opencode-flake";
    codex-cli.url = "github:sadjow/codex-cli-nix";
    nixvim.url = "github:dtvillafana/nixvim";
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  # Define the outputs generated from those inputs
  outputs =
    {
      self,
      nixpkgs,
      determinate,
      home-manager,
      sops-nix,
      nixvim,
      claude-code,
      codex-cli,
      opencode-tui,
      ...
    }:
    let
      system = "x86_64-linux";
      nodes = [
        "hpenvynix"
        "thinkpad"
        "rogdesktop"
      ];
      configuration = (
        # Function that templates out a value for the `nixosConfigurations` attrset.
        # Used for bundling a nixos configuration for the node to be used for autoUpgrades after deployment.
        nodename:
        nixpkgs.lib.nixosSystem {
          system = system;
          modules = [
            determinate.nixosModules.default
            home-manager.nixosModules.home-manager
            sops-nix.nixosModules.sops
            ./os-configs/common.nix
            ./os-configs/${nodename}
            ./hardware-configs/${nodename}.nix
            ./home.nix
          ];
          specialArgs = {
            # additional arguments to pass to modules
            self = self;
            nodename = nodename;
            modulesPath = "${nixpkgs}/nixos/modules";
            home-manager = home-manager;
            nixpkgs = nixpkgs;
            nixvim = nixvim;
            system = system;
            claude-code = claude-code;
            codex-cli = codex-cli;
            opencode-tui = opencode-tui;
          };
        }
      );
    in
    {
      # This evaluates to: {"hpenvynix" = nixpkgs.lib.nixosSystem {...}; ... }
      nixosConfigurations = builtins.listToAttrs (
        map (nodename: {
          "name" = "${nodename}";
          "value" = configuration nodename;
        }) nodes # List of nodes to generate images for
      );
    };
}
