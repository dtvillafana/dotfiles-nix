{
    description = "A basic NixOS flake configuration";

    # Define the inputs (dependencies) for this flake
    inputs = {
        # Use the official NixOS package repository
        nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

        # You can add other inputs like:
        # home-manager.url = "github:nix-community/home-manager";
        # home-manager.inputs.nixpkgs.follows = "nixpkgs";
    };

    # Define the outputs generated from those inputs
    outputs = { self, nixpkgs, ... }@inputs: {
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
                ];
            };
        };
    };
}
