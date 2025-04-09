{
    description = "A basic NixOS flake configuration";

    # Define the inputs (dependencies) for this flake
    inputs = {
        determinate.url = "https://flakehub.com/f/DeterminateSystems/determinate/0.1";
        nixpkgs.url = "https://flakehub.com/f/NixOS/nixpkgs/0.2405.0";

         # Use the matching release branch of home-manager for your nixpkgs version
        home-manager = {
            url = "github:nix-community/home-manager/release-24.05";
            # This ensures home-manager uses the same nixpkgs as your system
            inputs.nixpkgs.follows = "nixpkgs";
        };
    };

    # Define the outputs generated from those inputs
    outputs = { self, nixpkgs, determinate, home-manager, ... }@inputs: {
        # Define a NixOS configuration
        nixosConfigurations = {
            # Replace "my-system" with your hostname
            "hpenvynix" = nixpkgs.lib.nixosSystem {
                system = "x86_64-linux"; # Or other platform like aarch64-linux

                specialArgs = {
                    inherit (nixpkgs) lib;
                    modulesPath = "${nixpkgs}/nixos/modules";
                    home-manager = home-manager;
                };

                modules = [
                    determinate.nixosModules.default
                    home-manager.nixosModules.home-manager
                    ./configuration.nix
                    ./hardware-configuration.nix
                    ./home.nix
                ];
            };
        };
    };
}
