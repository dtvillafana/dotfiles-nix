{ self, inputs, ... }:
{
  flake.nixOnDroidConfigurations.default = inputs.nix-on-droid.lib.nixOnDroidConfiguration {
    pkgs = import inputs.nixpkgs {
      system = "aarch64-linux";
      overlays = [ inputs.nix-on-droid.overlays.default ];
    };
    home-manager-path = inputs.home-manager.outPath;
    modules = [
      ({ pkgs, ... }: {
        environment.packages = [ pkgs.neovim ];
        environment.etcBackupExtension = ".bak";
        system.stateVersion = "24.05";
        nix.extraOptions = ''
          experimental-features = nix-command flakes
        '';

        home-manager = {
          useGlobalPkgs = true;
          backupFileExtension = "hm-bak";
          config = {
            imports = [
              self.homeModules.git
              self.homeModules.tmux
            ];
            home.stateVersion = "24.05";
          };
        };
      })
    ];
  };
}
