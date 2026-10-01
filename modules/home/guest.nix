{ self, inputs, ... }:
{
  flake.nixosModules.guestHome =
    { config, pkgs, ... }:
    {
      imports = [ self.nixosModules.hyprlandDesktop ];
      users.users.guest = {
        isNormalUser = true;
        description = "guest";
        extraGroups = [
          config.programs.ydotool.group
          "networkmanager"
          "wheel"
          "dialout"
          "tty"
        ];
        packages = with pkgs; [
          git
          neovim
          curl
        ];
        shell = pkgs.zsh;
      };
      users.groups.guest = { };

      home-manager.users.guest =
        { pkgs, ... }:
        {
          imports = [
            inputs.nix-index-database.homeModules.nix-index
            self.homeModules.hyprland
            self.homeModules.launcher
            self.homeModules.browsers
            self.homeModules.monitors
            self.homeModules.zathura
          ];

          home.username = "guest";
          home.homeDirectory = "/home/guest";
          home.sessionPath = [
            "$HOME/.nix-profile/bin"
            "/etc/profiles/per-user/guest/bin"
            "/run/wrappers/bin"
            "/run/current-system/sw/bin"
          ];

          programs.home-manager.enable = true;

          programs.ghostty = {
            enable = true;
            settings = {
              window-decoration = "none";
              gtk-titlebar = false;
              keybind = [
                "ctrl+enter=unbind"
              ];
            };
          };

          home.packages = with pkgs; [
            age
            audacity
            bc
            blueman
            brightnessctl
            btop
            fd
            fzf
            gemini-cli
            git
            gopass
            jq
            lazygit
            networkmanager
            pwgen-secure
            python313FreeThreading
            ripgrep
            sops
            vlc
            wireguard-tools
            xournalpp
            zathura
            zbar
            zenity
            zip
          ];

          programs.direnv = {
            enable = true;
            enableZshIntegration = true;
            nix-direnv.enable = true;
          };

          programs.zsh = {
            enable = true;
          };

          home.stateVersion = "25.11";
        };
    };
}
