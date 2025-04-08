{
    description = "A basic NixOS flake configuration";

    # Define the inputs (dependencies) for this flake
    inputs = {
        determinate.url = "https://flakehub.com/f/DeterminateSystems/determinate/0.1";
        nixpkgs.url = "https://flakehub.com/f/NixOS/nixpkgs/0.2405.0";

        # You can add other inputs like:
        home-manager.url = "github:nix-community/home-manager";
        home-manager.inputs.nixpkgs.follows = "nixpkgs";
    };

    # Define the outputs generated from those inputs
    outputs = { self, nixpkgs, determinate, ... }@inputs: {
        # Define a NixOS configuration
        nixosConfigurations = {
            # Replace "my-system" with your hostname
            "hpenvynix" = nixpkgs.lib.nixosSystem {
                system = "x86_64-linux"; # Or other platform like aarch64-linux

                specialArgs = {
                    inherit (nixpkgs) lib;
                    modulesPath = "${nixpkgs}/nixos/modules";
                };

                modules = [
                    ./configuration.nix
                    ./hardware-configuration.nix
                    determinate.nixosModules.default
                ];
            };
        };
    };
}
