{ self, ... }:
{
  flake.nixosModules.virHome =
    {
      system,
      opencode-tui,
      codex-cli,
      claude-code,
      pkgs,
      ...
    }:
    {
      imports = [
        self.nixosModules.browsers
        self.nixosModules.git
        self.nixosModules.git-repos
        self.nixosModules.launcher
        self.nixosModules.monitors
        self.nixosModules.ssh
        self.nixosModules.terminal
        self.nixosModules.tmux
        self.nixosModules.xsession
        self.nixosModules.zathura
        self.nixosModules.zsh
      ];

      home-manager.useGlobalPkgs = false;
      home-manager.useUserPackages = true;
      home-manager.backupFileExtension = "hm-bak";
      home-manager.extraSpecialArgs = {
        claude-code = claude-code;
      };
      home-manager.sharedModules = [
        {
          nixpkgs.overlays = [ claude-code.overlays.default ];
        }
      ];
      users.users.vir = {
        isNormalUser = true;
        description = "vir";
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
      users.groups.vir = { };
      home-manager.users.vir =
        { pkgs, ... }:
        {
          home.username = "vir";
          home.homeDirectory = "/home/vir";

          home.packages = with pkgs; [
            age
            arandr
            audacity
            bc
            blueman
            brightnessctl
            btop
            codex-cli.packages.${system}.default
            dunst
            fd
            feh
            fzf
            gemini-cli
            git
            gopass
            jq
            krita
            lazygit
            libreoffice
            networkmanager
            nixfmt-tree
            opencode-tui.packages.${system}.default
            pkgs.claude-code
            pwgen-secure
            python314FreeThreading
            ripgrep
            ripgrep-all
            rofi
            scli
            scrot
            signal-desktop
            sops
            sshfs
            telegram-desktop
            vlc
            wireguard-tools
            xdotool
            xournalpp
            xss-lock
            zbar
            zenity
            zip
          ];

          home.sessionPath = [
            "$HOME/.nix-profile/bin"
            "/etc/profiles/per-user/vir/bin"
            "/run/wrappers/bin"
            "/run/current-system/sw/bin"
          ];

          nixpkgs.config.allowUnfree = true;

          programs.home-manager.enable = true;

          home.file = {
            ".ssh/id_ecdsa.pub".text =
              "ecdsa-sha2-nistp521 AAAAE2VjZHNhLXNoYTItbmlzdHA1MjEAAAAIbmlzdHA1MjEAAACFBAG8NzNAYDdt66g3YlH9/JpemTq87v5auOVQMJ128U78Kwyc9Dq8vYELxpglHWg4ILwmNp8mgAC9tDnmNI24PY1RgQG7Mq2cIciPPf8B8ebR3v0nMi5KHRR5cCf7FXpPqbPMAuqzz748gnCkpGypdquz2Psywxe02b/jwLDNrhoKORmJiA== vir@nixos";
            ".local/share/gopass/stores/.keep" = {
              source = builtins.toFile "keep" "";
            };
            ".config/containers/policy.json".text = ''
              {
                  "default": [
                      {
                          "type": "insecureAcceptAnything"
                      }
                  ]
              }
            '';
          };

          home.stateVersion = "25.11";
        };
    };
}
