{ self, inputs, ... }:
{
  flake.nixosModules.virHome =
    {
      system,
      llm-agents,
      nixvim,
      pkgs,
      ...
    }:
    {
      imports = [
        self.nixosModules.xorg
      ];

      home-manager.useGlobalPkgs = false;
      home-manager.useUserPackages = true;
      home-manager.backupFileExtension = "hm-bak";
      home-manager.extraSpecialArgs = {
        inherit llm-agents nixvim system;
      };
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
          imports = [
            inputs.nix-index-database.homeModules.nix-index
            self.homeModules.i3
            self.homeModules.browsers
            self.homeModules.zathura
            self.homeModules.ssh
            self.homeModules.terminal
            self.homeModules.monitors
            self.homeModules.launcher
            self.homeModules.git-repos
            self.homeModules.git
            self.homeModules.tmux
            self.homeModules.zsh
          ];

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
            dunst
            fd
            feh
            fzf
            gemini-cli
            git
            gopass
            heroic
            jq
            krita
            lazygit
            libreoffice
            llm-agents.packages.${system}.agent-deck
            llm-agents.packages.${system}.claude-code
            llm-agents.packages.${system}.handy
            llm-agents.packages.${system}.openclaw
            llm-agents.packages.${system}.opencode
            llm-agents.packages.${system}.workmux
            networkmanager
            networkmanagerapplet
            networkmanager-fortisslvpn
            nixfmt-tree
            nvtopPackages.full
            openfortivpn
            openfortivpn-webview
            pwgen-secure
            python313
            ripgrep
            ripgrep-all
            rofi
            scli
            scrot
            signal-cli
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
            (pkgs.writeShellScriptBin "forti-sso-connect" ''
              set -euo pipefail

              if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
                echo "Usage: forti-sso-connect <gateway[:port]> [username]"
                echo "Example: forti-sso-connect vpn.company.com:443 alice"
                exit 1
              fi

              gateway="$1"
              username="''${2:-}"

              if [ -n "$username" ]; then
                user_arg=("-u" "$username")
              else
                user_arg=()
              fi

              echo "Opening browser for SSO login..."
              echo "URL: https://$gateway"
              openfortivpn-webview "https://$gateway"

              cookie="$(zenity --password --title="Fortinet SSO" --text="Paste SVPNCOOKIE from webview output")"
              if [ -z "$cookie" ]; then
                echo "No cookie provided. Aborting."
                exit 1
              fi

              printf '%s\n' "$cookie" | openfortivpn "$gateway" "''${user_arg[@]}" --cookie-on-stdin
            '')
          ];

          home.sessionPath = [
            "$HOME/.nix-profile/bin"
            "/etc/profiles/per-user/vir/bin"
            "/run/wrappers/bin"
            "/run/current-system/sw/bin"
          ];

          home.sessionVariables = {
            HERMES_HOME = "/var/lib/hermes/.hermes";
          };

          nixpkgs.config.allowUnfree = true;

          programs.home-manager.enable = true;

          systemd.user.services.handy = {
            Unit = {
              Description = "Handy background service";
              After = [ "graphical-session.target" ];
              PartOf = [ "graphical-session.target" ];
            };
            Service = {
              ExecStart = "${llm-agents.packages.${system}.handy}/bin/handy --start-hidden";
              Restart = "on-failure";
            };
            Install = {
              WantedBy = [ "graphical-session.target" ];
            };
          };

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
