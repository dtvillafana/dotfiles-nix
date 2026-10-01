{ self, ... }:
{
  flake.nixosModules.common =
    {
      config,
      lib,
      pkgs,
      nodename,
      secretsEnabled ? true,
      ...
    }:
    let
      profileUsers = lib.filter (user: builtins.hasAttr user config.users.users) [
        "vir"
        "capcu"
      ];
      headscaleGitDns = pkgs.writeShellApplication {
        name = "headscale-git-dns";
        runtimeInputs = [
          pkgs.jq
          pkgs.systemd
          pkgs.tailscale
        ];
        text = ''
          if ! tailscale status --json --peers=false | jq -e '.BackendState == "Running"' >/dev/null; then
            echo "Headscale is not connected yet." >&2
            exit 1
          fi

          exit_node_enabled="$(tailscale debug prefs | jq -r '(.ExitNodeID // "") != "" or (.ExitNodeIP // "") != ""')"
          if [ "$exit_node_enabled" = false ]; then
            resolvectl domain tailscale0 '~git.dvilla.me'
            resolvectl default-route tailscale0 false
            resolvectl dns tailscale0 100.100.100.100
          fi
        '';
      };
      libreofficeDraw = pkgs.symlinkJoin {
        name = "libreoffice-draw";
        paths = [
          (pkgs.writeShellApplication {
            name = "libreoffice-draw";
            runtimeInputs = [ pkgs.libreoffice ];
            text = ''
              exec libreoffice --draw "$@"
            '';
          })
          (pkgs.makeDesktopItem {
            name = "libreoffice-draw";
            desktopName = "LibreOffice Draw";
            exec = "libreoffice-draw %U";
            categories = [
              "Graphics"
              "VectorGraphics"
            ];
            type = "Application";
          })
        ];
      };
    in
    {

      sops = lib.mkIf secretsEnabled (
        {
          defaultSopsFile = self + /secrets/secrets.json;
          defaultSopsFormat = "json";
          secrets.headscale_preauth_key = {
            mode = "0400";
          };
        }
        // lib.optionalAttrs (profileUsers != [ ]) {
          age.sshKeyPaths = map (user: "/home/${user}/.ssh/id_ed25519") profileUsers;
        }
      );

      networking.hostName = nodename;

      fonts.packages = with pkgs.nerd-fonts; [
        jetbrains-mono
        symbols-only
      ];

      services.resolved.enable = true;

      networking.networkmanager.enable = true;
      services.tailscale = {
        enable = true;
      }
      // lib.optionalAttrs secretsEnabled {
        authKeyFile = config.sops.secrets.headscale_preauth_key.path;
        extraUpFlags = [
          "--login-server=https://ts.dvilla.me"
          "--exit-node="
          "--accept-dns=false"
        ];
        extraSetFlags = [
          "--exit-node="
          "--accept-dns=false"
        ];
      };

      systemd.services.headscale-git-dns = lib.mkIf (secretsEnabled && config.services.tailscale.enable) {
        description = "Route Git DNS through Headscale when the exit node is off";
        wantedBy = [
          "multi-user.target"
          "systemd-resolved.service"
          "tailscaled.service"
        ];
        after = [
          "systemd-resolved.service"
          "tailscaled.service"
          "tailscaled-autoconnect.service"
          "tailscaled-set.service"
        ];
        serviceConfig = {
          Type = "oneshot";
          Restart = "on-failure";
          RestartSec = "5s";
        };
        script = lib.getExe headscaleGitDns;
      };
      time.timeZone = "America/North_Dakota/New_Salem";

      i18n.defaultLocale = "en_US.UTF-8";

      i18n.extraLocaleSettings = {
        LC_ADDRESS = "en_US.UTF-8";
        LC_IDENTIFICATION = "en_US.UTF-8";
        LC_MEASUREMENT = "en_US.UTF-8";
        LC_MONETARY = "en_US.UTF-8";
        LC_NAME = "en_US.UTF-8";
        LC_NUMERIC = "en_US.UTF-8";
        LC_PAPER = "en_US.UTF-8";
        LC_TELEPHONE = "en_US.UTF-8";
        LC_TIME = "en_US.UTF-8";
      };

      services.printing.enable = true;

      documentation.nixos.enable = false;
      home-manager.sharedModules = [
        {
          manual.manpages.enable = false;
          manual.json.enable = false;
        }
      ];

      services.pulseaudio.enable = false;
      security.rtkit.enable = true;
      services.pipewire = {
        enable = true;
        alsa.enable = true;
        alsa.support32Bit = true;
        pulse.enable = true;
      };

      security.sudo.wheelNeedsPassword = false;

      nixpkgs.config = {
        allowUnfree = true;
      };

      nix.settings = {
        experimental-features = [
          "nix-command"
          "flakes"
          "wasm-builtin"
          "parallel-eval"
        ];
        max-jobs = "auto";
        auto-optimise-store = true;
        http-connections = 50;
        connect-timeout = 5;
        fallback = true;
        builders-use-substitutes = true;
        extra-substituters = [ "https://cache.numtide.com" ];
        extra-trusted-public-keys = [
          "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
        ];
      };

      nix.gc = {
        automatic = true;
        dates = "weekly";
        options = "--delete-older-than 30d";
      };

      environment.systemPackages = with pkgs; [
        curl
        self.packages.${pkgs.stdenv.hostPlatform.system}.excise
        file
        gh
        git
        git-agecrypt
        gnupg
        libreofficeDraw
        neovim
        onlyoffice-desktopeditors
        self.packages.${pkgs.stdenv.hostPlatform.system}.open-browser-use
        pavucontrol
        pinentry-tty
        ssh-to-age
        tailscale
        unzip
        wget
        (pkgs.writeShellApplication {
          name = "headscale-toggle";
          runtimeInputs = [
            pkgs.jq
            pkgs.tailscale
          ];
          text = ''
            if [ "$#" -ne 0 ]; then
              echo "Usage: headscale-toggle" >&2
              exit 1
            fi

            if ! tailscale status --json --peers=false | jq -e '.BackendState == "Running"' >/dev/null; then
              echo "Headscale is not connected; check tailscaled-autoconnect.service." >&2
              exit 1
            fi

            # Preferences describe the selected exit node even when it is offline
            # or the runtime status has not caught up yet.
            exit_node_enabled="$(tailscale debug prefs | jq -r '(.ExitNodeID // "") != "" or (.ExitNodeIP // "") != ""')"
            if [ "$exit_node_enabled" = true ]; then
              /run/wrappers/bin/sudo ${lib.getExe pkgs.tailscale} set --exit-node= --accept-dns=false
              /run/wrappers/bin/sudo ${lib.getExe headscaleGitDns}
              echo "Headscale exit node and general DNS disabled; Git remains on Headscale."
            else
              /run/wrappers/bin/sudo ${lib.getExe pkgs.tailscale} set --exit-node=nixos-headscale-linode --accept-dns=true
              echo "Headscale exit node and DNS enabled."
            fi
          '';
        })
      ];

      programs.nix-ld.enable = true;

      programs.gnupg.agent = {
        enable = true;
        enableSSHSupport = true;
      };
      programs.zsh.enable = true;

      services.openssh.enable = true;
      hardware.bluetooth.enable = true;

      system.stateVersion = "24.11";
    };
}
