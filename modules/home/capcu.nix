{ self, inputs, ... }:
{
  flake.nixosModules.capcuHome =
    {
      config,
      system,
      llm-agents,
      nixvim,
      pkgs,
      ...
    }:
    let
      cifsMount = device: {
        inherit device;
        fsType = "cifs";
        options = [
          "credentials=${config.sops.secrets.windows-share-capcu.path}"
          "uid=capcu"
          "gid=capcu"
          "file_mode=0600"
          "dir_mode=0700"
          "vers=3.0"
          "_netdev"
          "nofail"
          "x-systemd.automount"
          "x-systemd.idle-timeout=10min"
        ];
      };
    in
    {
      boot.supportedFilesystems = [ "cifs" ];

      systemd.tmpfiles.rules = [
        "d /home/capcu/mounts/n 0700 capcu capcu -"
        "d /home/capcu/mounts/t 0700 capcu capcu -"
        "d /home/capcu/mounts/u 0700 capcu capcu -"
      ];

      fileSystems = {
        "/home/capcu/mounts/n" = cifsMount "//ccufs1.capcu.org/Data";
        "/home/capcu/mounts/t" = cifsMount "//ccufs2.capcu.org/Data";
        "/home/capcu/mounts/u" = cifsMount "//ccufs3.capcu.org/Data";
      };

      imports = [
        self.nixosModules.xorg
        self.nixosModules.work_sops
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
            /run/current-system/sw/bin/resolvectl domain "$interface" 'capcu.org'
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
            self.homeModules.capcuGit
            self.homeModules.ai
            self.homeModules.tmux
            self.homeModules.zsh
          ];

          home.username = "capcu";
          home.homeDirectory = "/home/capcu";

          programs.chromium = {
            enable = true;
            commandLineArgs = [ "--password-store=basic" ];
            extensions = [
              { id = "dbepggeogbaibhgnhhndojpepiihcmeb"; }
              { id = "ppnbnpeolgkicgegkbkbjmhlideopiji"; }
            ];
          };

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
            networkmanager-fortisslvpn
            networkmanagerapplet
            nixfmt-tree
            nvtopPackages.full
            openfortivpn
            openfortivpn-webview
            pwgen-secure
            python313
            remmina
            ripgrep
            ripgrep-all
            rofi
            scli
            scrot
            sops
            sshfs
            teams-for-linux
            vlc
            webex
            wireguard-tools
            xdotool
            xournalpp
            xss-lock
            zbar
            zenity
            zip
            (pkgs.writeShellScriptBin "forti-sso-toggle" ''
              set -euo pipefail

              if [ "$#" -ne 0 ]; then
                echo "Usage: forti-sso-toggle"
                exit 1
              fi

              gateway="ra.capcu.org:4433"
              config="$HOME/.config/openfortivpn/capcu.conf"

              if sudo pgrep -f -- "^openfortivpn -c $config" >/dev/null; then
                echo "Disconnecting VPN..."
                sudo pkill -TERM -f -- "^openfortivpn -c $config"
                echo "VPN disconnected."
                exit 0
              fi

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
            ".config/agent-deck/config.toml".text = ''
              default_tool = "claude"
              theme = "dark"

              [claude]
              dangerous_mode = false

              [global_search]
              enabled = true
              tier = "auto"
              recent_days = 90

              [instances]
              allow_multiple = true
            '';
          };

          home.stateVersion = "25.11";
        };
    };

  flake.nixosModules.work_sops =
    { config, ... }:
    let
      home = config.users.users.capcu.home;
      mkWorkSecret = _: {
        sopsFile = self + /secrets/work.json;
        format = "json";
        owner = "capcu";
        group = "capcu";
      };
      mkTemplate = name: content: {
        inherit content;
        path = "${home}/.${name}";
        owner = config.users.users.capcu.name;
        mode = "0600";
      };
    in
    {
      sops = {
        # This attrset merges with the shared secrets declared by common.
        secrets = {
          gitea_token = mkWorkSecret "gitea_token";
          ansible_pass = mkWorkSecret "ansible_pass";
          git_gitea = mkWorkSecret "git_gitea";
          capcu_master_key = mkWorkSecret "capcu_master_key";
          windows-share-capcu = {
            sopsFile = self + /secrets/work.json;
            format = "json";
            owner = "root";
            group = "root";
            mode = "0400";
          };
        };

        templates = {
          "vault-pass.txt" = mkTemplate "vault-pass.txt" "${config.sops.placeholder.ansible_pass}";
          "git-credentials-github" =
            mkTemplate "git-credentials-github" "https://dtvillafana:${config.sops.placeholder.git_github}@github.com\n";
          "git-credentials-gitlab" =
            mkTemplate "git-credentials-gitlab" "https://dvillafanaiv:${config.sops.placeholder.git_gitlab_pat}@gitlab.com\n";
          "git-credentials-gitea" =
            mkTemplate "git-credentials-gitea" "https://dvillafana:${config.sops.placeholder.git_gitea}@ccugitea.capcu.org\n";
        };
      };
    };

  flake.homeModules.capcuGit =
    { pkgs, osConfig, ... }:
    let
      giteaCredentialHelper = "store --file=${osConfig.sops.templates."git-credentials-gitea".path}";
    in
    {
      programs.git = {
        enable = true;
        settings = {
          user = {
            name = "David Villafaña";
            email = "david.villafana@capcu.org";
          };
          core.sshCommand = "${pkgs.openssh}/bin/ssh";
          credential = {
            "http://ccugitea.capcu.org:3000".helper = giteaCredentialHelper;
            "http://ccugitea.capcu.org".helper = giteaCredentialHelper;
            "https://ccugitea.capcu.org".helper = giteaCredentialHelper;
            "https://github.com".helper = "store --file=${
              osConfig.sops.templates."git-credentials-github".path
            }";
            "https://gitlab.com".helper = "store --file=${
              osConfig.sops.templates."git-credentials-gitlab".path
            }";
          };
        };
      };
    };

  flake.homeModules.git-repos =
    { pkgs, osConfig, ... }:
    {
      home.file.".local/bin/sync-work-repos" = {
        executable = true;
        text = ''
          #!/bin/sh
          GITEA_TOKEN=$(cat ${osConfig.sops.secrets.gitea_token.path})
          GITEA_URL="https://ccugitea.capcu.org"
          REPOS_DIR="$HOME/capcu-git-repos"

          mkdir -p "$REPOS_DIR"

          page=1
          while true; do
            repos=$(${pkgs.curl}/bin/curl -s -H "Authorization: token $GITEA_TOKEN" \
              "$GITEA_URL/api/v1/user/repos?page=$page&limit=50" | ${pkgs.jq}/bin/jq -r '[.[] | select(.mirror != true)] | .[].full_name // empty')

            if [ -z "$repos" ]; then
              break
            fi

            for repo in $repos; do
              repo_path="$REPOS_DIR/$repo"
              if [ ! -d "$repo_path" ]; then
                echo "Cloning $repo..."
                mkdir -p "$(dirname "$repo_path")"
                ${pkgs.git}/bin/git clone "$GITEA_URL/$repo" "$repo_path" || true
              else
                echo "Pulling $repo..."
                (cd "$repo_path" && ${pkgs.git}/bin/git pull) || true
              fi
            done

            page=$((page + 1))
          done
        '';
      };

      programs.zsh.shellAliases.sync-work-repos = "$HOME/.local/bin/sync-work-repos";
    };
}
