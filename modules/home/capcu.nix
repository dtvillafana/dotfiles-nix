{ self, inputs, ... }:
{
  flake.nixosModules.capcuHome =
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
      users.users.capcu = {
        isNormalUser = true;
        description = "capcu";
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
      users.groups.capcu = { };

      networking.networkmanager.plugins = with pkgs; [
        networkmanager-fortisslvpn
      ];

      environment.etc = {
        "ppp/ip-up" = {
          mode = "0755";
          text = ''
            #!${pkgs.runtimeShell}
            set -eu

            interface="$1"
            ipparam="''${6:-}"

            if [ "$ipparam" != "capcu" ]; then
              exit 0
            fi

            /run/current-system/sw/bin/resolvectl dns "$interface" 172.20.102.25 172.20.102.26
            /run/current-system/sw/bin/resolvectl domain "$interface" '~capcu.org'
            /run/current-system/sw/bin/resolvectl default-route "$interface" false
          '';
        };

        "ppp/ip-down" = {
          mode = "0755";
          text = ''
            #!${pkgs.runtimeShell}
            set -eu

            interface="$1"
            ipparam="''${6:-}"

            if [ "$ipparam" != "capcu" ]; then
              exit 0
            fi

            /run/current-system/sw/bin/resolvectl revert "$interface" || true
          '';
        };
      };

      home-manager.users.capcu =
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

          home.username = "capcu";
          home.homeDirectory = "/home/capcu";

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
            teams-for-linux
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

              if [ "$#" -ne 0 ]; then
                echo "Usage: forti-sso-connect"
                exit 1
              fi

              gateway="ra.capcu.org:4433"
              config="$HOME/.config/openfortivpn/capcu.conf"

              echo "Opening browser for SSO login..."
              echo "URL: https://$gateway"
              cookie="$(openfortivpn-webview "$gateway" | grep '^SVPNCOOKIE=' | sed 's/^SVPNCOOKIE=//')"
              if [ -z "$cookie" ]; then
                echo "No cookie found in webview output. Aborting."
                exit 1
              fi

              state_dir="''${XDG_STATE_HOME:-$HOME/.local/state}/forti-sso-connect"
              mkdir -p "$state_dir"
              log="$state_dir/capcu.log"
              cookie_file="$(mktemp "''${TMPDIR:-/tmp}/forti-sso-cookie.XXXXXX")"
              chmod 600 "$cookie_file"
              trap 'rm -f "$cookie_file"' EXIT

              printf '%s\n' "$cookie" >"$cookie_file"
              : >"$log"

              (
                sudo openfortivpn -c "$config" --persistent=30 --cookie-on-stdin <"$cookie_file" >"$log" 2>&1
                rm -f "$cookie_file"
              ) &
              vpn_pid="$!"
              trap - EXIT

              echo "Starting VPN in background..."
              echo "Log: $log"

              attempt=0
              while [ "$attempt" -lt 60 ]; do
                if grep -q 'Tunnel is up and running' "$log"; then
                  echo "VPN connected. Background PID: $vpn_pid"
                  exit 0
                fi

                if ! kill -0 "$vpn_pid" 2>/dev/null; then
                  echo "VPN process exited before connecting. Log: $log"
                  exit 1
                fi

                attempt="$((attempt + 1))"
                sleep 1
              done

              echo "Timed out waiting for VPN connection. Process is still running as PID $vpn_pid. Log: $log"
              exit 1
            '')
          ];

          home.sessionPath = [
            "$HOME/.nix-profile/bin"
            "/etc/profiles/per-user/capcu/bin"
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
            ".config/openfortivpn/capcu.conf".text = ''
              host = ra.capcu.org
              port = 4433
              trusted-cert = 4e582e8dacfa3ddf26c5c9aed13d65d8c931a7184da1155f72e00b6b068052f8

              set-routes = 1
              set-dns = 0
              pppd-use-peerdns = 0
              pppd-ipparam = capcu
            '';
          };

          home.stateVersion = "25.11";
        };
    };
}
