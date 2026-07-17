{ self, inputs, ... }:
{
  flake.nixosModules.guestHome =
    { pkgs, ... }:
    {
      users.users.guest = {
        isNormalUser = true;
        description = "guest";
        extraGroups = [
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

      services.desktopManager.plasma6.enable = true;
      home-manager.users.guest =
        { pkgs, ... }:
        {
          imports = [
            inputs.nix-index-database.homeModules.nix-index
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

          nixpkgs.config.allowUnfree = true;

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
            arandr
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
            libreoffice
            networkmanager
            pwgen-secure
            python313FreeThreading
            ripgrep
            signal-desktop
            sops
            telegram-desktop
            vlc
            wireguard-tools
            xdotool
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

          xsession = {
            enable = true;
            scriptPath = ".xinitrc";
            windowManager.command = "exec startplasma-x11";
          };

          home.stateVersion = "25.11";
        };
    };
}
