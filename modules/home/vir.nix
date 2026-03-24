{ self, inputs, ... }:
{
  flake.nixosModules.virHome =
    {
      config,
      pkgs,
      home-manager,
      nodename,
      system,
      opencode-tui,
      codex-cli,
      claude-code,
      ...
    }:
    let
      enable_git_repo_cloning =
        if (nodename == "hpenvynix" || nodename == "thinkpad" || nodename == "rogdesktop") then
          true
        else
          false;
      external_git_repos = [
        {
          name = "nixvim";
          url = "https://dtvillafana:$(cat ${config.sops.secrets.git_github.path})@github.com/dtvillafana/nixvim";
          path = "$HOME/git-repos/nixvim";
        }
        {
          name = "nixvim-for-pr";
          url = "https://dtvillafana:$(cat ${config.sops.secrets.git_github.path})@github.com/dtvillafana/nixvim-for-pr";
          path = "$HOME/git-repos/nixvim-for-pr";
        }
        {
          name = "nostr-playground";
          url = "https://dtvillafana:$(cat ${config.sops.secrets.git_github.path})@github.com/dtvillafana/nostr-playground";
          path = "$HOME/git-repos/nostr-playground";
        }
        {
          name = "orgfiles";
          url = "https://dvillafanaiv:$(cat ${config.sops.secrets.git_gitlab.path})@gitlab.com/personal2673713/org.git";
          path = "$HOME/git-repos/orgfiles";
        }
        {
          name = "spectrum-orgfiles";
          url = "https://dvillafanaiv:$(cat ${config.sops.secrets.git_gitlab.path})@gitlab.com/spectrum-it-solutions/orgfiles.git";
          path = "$HOME/git-repos/spectrum-orgfiles";
        }
        {
          name = "homelab-nixos-generators";
          url = "https://dvillafanaiv:$(cat ${config.sops.secrets.git_gitlab.path})@gitlab.com/spectrum-it-solutions/nixos-generators.git";
          path = "$HOME/git-repos/homelab-nixos-generators";
        }
        {
          name = "i-got-a-buddy-web";
          url = "https://dtvillafana:$(cat ${config.sops.secrets.git_github.path})@github.com/dtvillafana/i-got-a-buddy-web";
          path = "$HOME/git-repos/i-got-a-buddy-web";
        }
        {
          name = "org-notifier";
          url = "https://dtvillafana:$(cat ${config.sops.secrets.git_github.path})@github.com/dtvillafana/org-notifier";
          path = "$HOME/git-repos/org-notifier";
        }
        {
          name = "liber-usualis";
          url = "https://dtvillafana:$(cat ${config.sops.secrets.git_github.path})@github.com/mkbertrand/liber-usualis";
          path = "$HOME/git-repos/liber-usualis";
        }
        {
          name = "finances";
          url = "vps:~/git-repos/finances";
          path = "$HOME/git-repos/finances";
        }
        {
          name = "dotfiles-nix";
          url = "https://dtvillafana:$(cat ${config.sops.secrets.git_github.path})@github.com/dtvillafana/dotfiles-nix";
          path = "$HOME/git-repos/dotfiles-nix";
        }
        {
          name = "cand-data-interface-api-service";
          url = "https://dtvillafana:$(cat ${config.sops.secrets.git_github.path})@github.com/spectrum-it-solutions/cand-data-interface-api-service";
          path = "$HOME/git-repos/cand-data-interface-api-service";
        }
        {
          name = "cand-data-interface-sql";
          url = "https://dtvillafana:$(cat ${config.sops.secrets.git_github.path})@github.com/spectrum-it-solutions/cand-data-interface-sql";
          path = "$HOME/git-repos/cand-data-interface-sql";
        }
        {
          name = "csc-106";
          url = "https://dtvillafana:$(cat ${config.sops.secrets.git_github.path})@github.com/dtvillafana/csc-106";
          path = "$HOME/git-repos/csc-106";
        }
        {
          name = "charachorder-config";
          url = "https://dtvillafana:$(cat ${config.sops.secrets.git_github.path})@github.com/dtvillafana/charachorder-config";
          path = "$HOME/git-repos/charachorder-config";
        }
        {
          name = "CSC-106-practice";
          url = "https://github.com/dtvillafana/CSC-106-practice";
          path = "$HOME/git-repos/CSC-106-practice";
        }
      ];

      make_git_forge_repo_action = repo: {
        name = "clone_${builtins.replaceStrings [ "-" ] [ "_" ] repo.name}";
        value = home-manager.lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          if [ ! -d "${repo.path}" ]; then
              export GIT_SSH="${pkgs.openssh}/bin/ssh"
              if ${pkgs.iputils}/bin/ping -c 1 github.com &> /dev/null; then
                  ${pkgs.git}/bin/git clone "${repo.url}" "${repo.path}"
              else
                  echo "Network unreachable. Skipping clone."
              fi
          else
              cd "${repo.path}" && ${pkgs.git}/bin/git pull || true
          fi
        '';
      };

      external_git_actions =
        if enable_git_repo_cloning then
          builtins.listToAttrs (map make_git_forge_repo_action external_git_repos)
        else
          { };

    in
    {
      imports = [
        self.nixosModules.zsh
        self.nixosModules.xsession
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
            i3lock
            jq
            krita
            lazygit
            libreoffice
            networkmanager
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

          programs.zathura = {
            enable = true;
            options = {
              selection-clipboard = "clipboard";
            };
          };

          programs.chromium = {
            enable = true;
            package = pkgs.brave;
            commandLineArgs = [ "--password-store=basic" ];
            extensions = [
              { id = "dbepggeogbaibhgnhhndojpepiihcmeb"; }
            ];
          };

          home.activation = external_git_actions;

          programs.ssh = {
            enable = true;
            enableDefaultConfig = false;
            matchBlocks = {
              "vps" = home-manager.lib.hm.dag.entryAnywhere {
                hostname = "104.207.135.195";
                identityFile = "${config.sops.secrets.git_vps.path}";
                user = "root";
                port = 4455;
              };
              "org" = home-manager.lib.hm.dag.entryAfter [ "vps" ] {
                hostname = "172.234.200.63";
                identityFile = "${config.sops.secrets.ssh_nix_key.path}";
                user = "vir";
                port = 22;
              };
              "*" = home-manager.lib.hm.dag.entryAfter [ "org" ] {
                identityFile = "${config.sops.secrets.ssh_nix_key.path}";
              };
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

          programs = {
            ghostty = {
              enable = true;
              settings = {
                window-decoration = "none";
                gtk-titlebar = false;
                keybind = [
                  "ctrl+enter=unbind"
                ];
              };
            };
          };

          programs.rofi = {
            enable = true;
            terminal = "ghostty";
            theme = "Arc-Dark";
            font = "DejaVu Sans Mono 11";
            extraConfig = {
              modi = "run,drun";
              icon-theme = "Papirus";
              show-icons = true;
              drun-display-format = "{name} [<span weight='light' size='small'><i>({generic})</i></span>]";
              disable-history = false;
              hide-scrollbar = true;
            };
          };

          programs.i3status = {
            enable = true;
            general = {
              output_format = "i3bar";
              colors = true;
              interval = 5;
            };
            modules = {
              "ethernet eth0" = {
                position = 1;
                settings = {
                  format_up = "E: %ip (%speed)";
                  format_down = "E: down";
                };
              };
              "wireless wlan0" = {
                position = 2;
                settings = {
                  format_up = "W: (%quality at %essid, %bitrate) %ip";
                  format_down = "W: down";
                };
              };
              "disk /" = {
                position = 3;
                settings = {
                  format = "%free";
                };
              };
              "battery 0" = {
                position = 4;
                settings = {
                  format = "%status %percentage %remaining %emptytime";
                  format_down = "";
                  status_chr = "⚡";
                  status_bat = "🔋";
                  status_unk = "";
                  status_full = "";
                  path = "/sys/class/power_supply/BAT%d/uevent";
                  low_threshold = 10;
                };
              };
              "memory" = {
                position = 5;
                settings = {
                  format = "Tax Fraud Docs: %used";
                  threshold_degraded = "10%";
                  format_degraded = "COMMIT MORE TAX FRAUD: %free";
                };
              };
              "tztime local" = {
                position = 7;
                settings = {
                  format = "%Y-%m-%d %H:%M:%S";
                };
              };
            };
          };

          programs.git = {
            enable = true;
            settings = {
              user = {
                name = "dtvillafana";
                email = "82293276+dtvillafana@users.noreply.github.com";
              };
              core.sshCommand = "${pkgs.openssh}/bin/ssh";
              credential."https://github.com".helper =
                "store --file=${config.users.users.vir.home}/.git-credentials-github";
              credential."https://gitlab.com".helper =
                "store --file=${config.users.users.vir.home}/.git-credentials-gitlab";
              credential."https://bitbucket.org".helper =
                "store --file=${config.users.users.vir.home}/.git-credentials-bitbucket";
            };
            lfs.enable = true;
          };

          services.autorandr.enable = true;
          programs.autorandr = {
            enable = true;
            profiles = {
              "thinkpad" = {
                fingerprint = {
                  eDP-1 = "00ffffffffffff0030e4900500000000001b010495221378eaa1c59459578f27205054000000010101010101010101010101010101012e3680a070381f403020350058c21000001ab62c80f4703816403020350058c21000001a000000fe004c4720446973706c61790a2020000000fe004c503135365746362d53504b360041";
                  HDMI-1 = "00ffffffffffff000472f3061e0600000c1e0103805021782a8195a355539f250a5054bfef80d1c0e1c0d100b300a940a9c0818081004ed470a0d0a0465030203400204f3100001a000000ff005448514141303031334530300a000000fd0030900fd93c000a202020202020000000fc005856333430434b20500a202020017b020346f04e101f0413031202110514013f6061230907078301000067030c001000383c681a000001013090ed67d85dc401788001e200eae3056000e30f0030e60607018b6011ef5170e0d4a0355000703a50204f3100001c6fc200a0a0a0555030203500204f3100001a3c41b8a060a0295030203a00204f3100001a000000c0";
                };
                config = {
                  eDP-1.enable = true;
                  HDMI-1.enable = true;
                  HDMI-1.primary = true;
                  DP-1.enable = false;
                  DP-2.enable = false;
                  HDMI-2.enable = false;
                  HDMI-1.mode = "2048x1152";
                  HDMI-1.position = "0x0";
                  eDP-1.mode = "1920x1080";
                  eDP-1.position = "2048x403";
                };
              };
              "rogdesktop" = {
                fingerprint = {
                  HDMI-1 = "00ffffffffffff000472f3061e0600000c1e0103805021782a8195a355539f250a5054bfef80d1c0e1c0d100b300a940a9c0818081004ed470a0d0a0465030203400204f3100001a000000ff005448514141303031334530300a000000fd0030900fd93c000a202020202020000000fc005856333430434b20500a202020017b020346f04e101f0413031202110514013f6061230907078301000067030c001000383c681a000001013090ed67d85dc401788001e200eae3056000e30f0030e60607018b6011ef5170e0d4a0355000703a50204f3100001c6fc200a0a0a0555030203500204f3100001a3c41b8a060a0295030203a00204f3100001a000000c0";
                };
                config = {
                  DVI-D-1.enable = false;
                  DP-1.enable = false;
                  DP-2.enable = false;
                  DP-3.enable = false;
                  HDMI-1.enable = true;
                  HDMI-1.crtc = 0;
                  HDMI-1.mode = "3440x1440";
                  HDMI-1.position = "0x0";
                  HDMI-1.primary = true;
                  HDMI-1.rate = "99.98";
                };
              };
            };
          };

          programs.qutebrowser = {
            enable = true;

            loadAutoconfig = false;

            keyBindings = {
              normal = {
                P = "hint links run :open -p {hint-url}";
                d = null;
                D = null;
              };
            };

            extraConfig = ''
              # Per-domain content settings
              config.set('content.cookies.accept', 'all', 'chrome-devtools://*')
              config.set('content.cookies.accept', 'all', 'devtools://*')

              config.set('content.headers.user_agent', 'Mozilla/5.0 ({os_info}) AppleWebKit/{webkit_version} (KHTML, like Gecko) {upstream_browser_key}/{upstream_browser_version} Safari/{webkit_version}', 'https://web.whatsapp.com/')
              config.set('content.headers.user_agent', 'Mozilla/5.0 ({os_info}; rv:90.0) Gecko/20100101 Firefox/90.0', 'https://accounts.google.com/*')
              config.set('content.headers.user_agent', 'Mozilla/5.0 ({os_info}) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/99 Safari/537.36', 'https://*.slack.com/*')

              config.set('content.images', True, 'chrome-devtools://*')
              config.set('content.images', True, 'devtools://*')

              config.set('content.javascript.enabled', True, 'chrome-devtools://*')
              config.set('content.javascript.enabled', True, 'devtools://*')
              config.set('content.javascript.enabled', True, 'chrome://*/*')
              config.set('content.javascript.enabled', True, 'qute://*/*')

              c.fileselect.handler = 'external'
              c.fileselect.single_file.command = ['${pkgs.zenity}/bin/zenity', '--file-selection']
              c.fileselect.folder.command = ['${pkgs.zenity}/bin/zenity', '--file-selection', '--directory']
              c.fileselect.multiple_files.command = ['sh', '-c', '${pkgs.zenity}/bin/zenity --file-selection --multiple | tr "|" "\\n"']
            '';

            aliases = {
              w = "session-save";
              q = "close";
              qa = "quit";
              wq = "quit --save";
              wqa = "quit --save";
              Wq = "quit --save";
              WQ = "quit --save";
              wQ = "quit --save";
            };

            settings = {
              content = {
                autoplay = false;
                images = true;
                cookies.accept = "all";
                javascript.enabled = true;
                headers.accept_language = "";
                headers.user_agent = "Mozilla/5.0 ({os_info}) AppleWebKit/{webkit_version} (KHTML, like Gecko) {upstream_browser_key}/{upstream_browser_version} Safari/{webkit_version}";
              };

              tabs = {
                last_close = "close";
                position = "bottom";
                show = "switching";
                show_switching_delay = 2000;
              };

              url = {
                default_page = "https://search.brave.com";
                incdec_segments = [
                  "path"
                  "query"
                ];
                start_pages = "https://search.brave.com";
              };

              colors = {
                webpage = {
                  preferred_color_scheme = "dark";
                };

                hints = {
                  fg = "chartreuse";
                  bg = "qlineargradient(x1:0, y1:0, x2:0, y2:1, stop:0 rgba(255, 0, 0, 0.8), stop:1 rgba(255, 0, 0, 0.8))";
                };
              };
            };

            searchEngines = {
              DEFAULT = "https://search.brave.com/search?q={}&source=web";
            };

            quickmarks = { };
          };

          home.stateVersion = "25.11";
        };
    };
}
