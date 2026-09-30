{ self, ... }:
{
  flake.nixosModules.capcuDellConfig =
    {
      config,
      hermes-agent,
      llm-agents,
      lib,
      pkgs,
      secretsEnabled ? true,
      ...
    }:
    let
      evdi = config.boot.kernelPackages.evdi.overrideAttrs {
        version = "1.15.0";
        src = pkgs.fetchFromGitHub {
          owner = "DisplayLink";
          repo = "evdi";
          tag = "v1.15.0";
          hash = "sha256-CXF7PvmrPjjNoWXbWxEkFE/Sw4bO6YqDplPwF/OxhB0=";
        };
        prePatch = "";
      };
      # Office FortiGate FG100FTK22020085 replaces the Headscale certificate
      # with a short-lived leaf and does not send its CA. tailscaled verifies
      # that leaf as root, so a capcu NSS exception cannot help. Trust only
      # the current leaf for ts.dvilla.me, and only inside tailscaled.
      fortinetHeadscaleBundle = "/var/lib/tailscale-fortinet-trust/ca-bundle.crt";
      trustFortinetHeadscaleCert = pkgs.writeShellApplication {
        name = "trust-fortinet-headscale-cert";
        runtimeInputs = [
          pkgs.coreutils
          pkgs.gawk
          pkgs.gnugrep
          pkgs.openssl
          pkgs.systemd
        ];
        text = ''
          host="ts.dvilla.me"
          issuer_cn="FG100FTK22020085"
          bundle="${fortinetHeadscaleBundle}"
          system_bundle="/etc/ssl/certs/ca-certificates.crt"
          restart=1
          if [ "''${1:-}" = "--no-restart" ]; then
            restart=0
          fi

          leaf="$(mktemp)"
          staged="$(mktemp)"
          trap 'rm -f "$leaf" "$staged"' EXIT
          mkdir -p "$(dirname "$bundle")"

          fetched=0
          if timeout 10 openssl s_client \
            -connect "$host:443" \
            -servername "$host" \
            -showcerts \
            </dev/null 2>/dev/null \
            | awk '/-----BEGIN CERTIFICATE-----/{capture=1} capture{print} /-----END CERTIFICATE-----/{exit}' >"$leaf" \
            && [ -s "$leaf" ] \
            && openssl x509 -in "$leaf" -noout -subject >/dev/null
          then
            fetched=1
          fi

          if [ "$fetched" -eq 1 ]; then
            subject="$(openssl x509 -in "$leaf" -noout -subject)"
            issuer="$(openssl x509 -in "$leaf" -noout -issuer)"
            san="$(openssl x509 -in "$leaf" -noout -ext subjectAltName 2>/dev/null || true)"
            if openssl verify -CAfile "$system_bundle" "$leaf" >/dev/null 2>&1; then
              cp "$system_bundle" "$staged"
            elif printf '%s\n%s\n' "$subject" "$san" | grep -F -e "CN=$host" -e "DNS:$host" >/dev/null \
              && printf '%s\n' "$issuer" | grep -F -q "CN=$issuer_cn"
            then
              cat "$system_bundle" "$leaf" >"$staged"
              echo "Trusting Fortinet temporary certificate for $host ($issuer)"
            else
              echo "Refusing certificate for $host ($subject / $issuer)" >&2
              cp "$system_bundle" "$staged"
            fi
          elif [ -s "$bundle" ]; then
            echo "Could not fetch a certificate for $host; keeping the existing bundle" >&2
            exit 0
          else
            echo "Could not fetch a certificate for $host; using the system bundle" >&2
            cp "$system_bundle" "$staged"
          fi

          if [ -f "$bundle" ] && cmp -s "$staged" "$bundle"; then
            exit 0
          fi

          install -m 644 "$staged" "$bundle"
          if [ "$restart" -eq 1 ] && systemctl is-active --quiet tailscaled.service; then
            systemctl restart tailscaled.service
            systemctl restart tailscaled-autoconnect.service || true
          fi
        '';
      };
    in
    {
      services.xserver.videoDrivers = [ "nvidia" ];

      services.xserver.windowManager.i3.enable = true;

      services.displayManager = {
        sddm.enable = true;
        defaultSession = "none+i3";
      };

      systemd.services.x0vncserver = {
        description = "Share the SDDM and i3 X11 display over VNC";
        wantedBy = [ "graphical.target" ];
        after = [ "display-manager.service" ];
        script = ''
          for xauthority in /run/sddm/xauth_*; do
            if [ -e "$xauthority" ]; then
              export XAUTHORITY="$xauthority"
              exec ${pkgs.tigervnc}/bin/x0vncserver -display :0 -localhost yes -rfbport 5901 -SecurityTypes None
            fi
          done
          exit 1
        '';
        serviceConfig = {
          Restart = "always";
          RestartSec = 2;
        };
      };

      hardware = {
        graphics.enable = true;
        nvidia = {
          package = config.boot.kernelPackages.nvidiaPackages.production;
          modesetting.enable = true;
          open = true;
          prime = {
            intelBusId = "PCI:0:2:0";
            nvidiaBusId = "PCI:2:0:0";
            offload.enableOffloadCmd = true;
            reverseSync.enable = true;
          };
        };
      };

      boot = {
        kernelPackages = pkgs.linuxPackages_6_18;
        crashDump.enable = true;
        extraModulePackages = [ evdi ];
        kernelModules = [ "evdi" ];
      };

      services.fwupd.enable = true;
      services.udev.packages = [ pkgs.displaylink ];

      nixpkgs.config.cudaCapabilities = [ "12.0" ];
      services.ollama.loadModels = lib.mkForce [
        "gpt-oss:20b"
        "nemotron-3.5-lightning:30b"
        "mistral-small3.2:24b"
      ];

      home-manager.users.capcu.opencode.settings = {
        "$schema" = "https://opencode.ai/config.json";
        providers = {
          "Local Ollama" = {
            package = "@opencode/ai/providers/openai-compatible";
            name = "Local Ollama";
            settings = {
              baseURL = "http://127.0.0.1:11434/v1";
            };
            models = {
              "nemotron-3.5-lightning:30b" = {
                name = "nemotron-3.5-lightning:30b";
              };
            };
          };
        };
      };

      sops.secrets."hermes-env-capcu" = lib.mkIf secretsEnabled {
        sopsFile = self + /secrets/hermes-dell.yaml;
        format = "yaml";
        owner = "capcu";
        group = "capcu";
        restartUnits = [
          "hermes-agent.service"
          "hermes-webui.service"
        ];
      };

      services.hermes-agent = lib.mkIf secretsEnabled {
        enable = true;
        package = hermes-agent.packages.${pkgs.stdenv.hostPlatform.system}.default;
        container.enable = false;
        addToSystemPackages = true;
        user = "capcu";
        group = "capcu";
        createUser = false;
        workingDirectory = "/home/capcu";
        extraPackages = config.home-manager.users.capcu.home.packages;
        environmentFiles = [
          config.sops.secrets."hermes-env-capcu".path
        ];
        environment = {
          API_SERVER_HOST = "127.0.0.1";
          API_SERVER_PORT = "8642";
        };
        settings = {
          toolsets = [ "all" ];
          platforms.api_server.enabled = true;
          model = {
            provider = "ollama";
            base_url = "http://127.0.0.1:11434/v1";
            default = "nemotron-3.5-lightning:30b";
            context_length = 65536;
          };
          max_turns = 100;
          agent = {
            max_turns = 60;
            verbose = true;
            tool_use_enforcement = true;
            intent_ack_continuation = true;
          };
          memory = {
            memory_enabled = true;
            user_profile_enabled = true;
          };
          terminal = {
            backend = "local";
            timeout = 180;
          };
        };
      };

      services.hermes-webui = lib.mkIf secretsEnabled {
        enable = true;
        user = "capcu";
        group = "capcu";
        stateDir = "/home/capcu/.hermes/webui";
        hermesHome = "${config.services.hermes-agent.stateDir}/.hermes";
        agent.package = config.services.hermes-agent.package;
        environmentFiles = [ config.sops.secrets."hermes-env-capcu".path ];
        extraEnvironment = {
          HERMES_WEBUI_CHAT_BACKEND = "gateway";
          HERMES_WEBUI_GATEWAY_BASE_URL = "http://${config.services.hermes-agent.environment.API_SERVER_HOST}:${config.services.hermes-agent.environment.API_SERVER_PORT}";
        };
      };

      systemd.services.hermes-agent = lib.mkIf secretsEnabled {
        after = [ "ollama-model-loader.service" ];
        requires = [ "ollama-model-loader.service" ];
        environment.HOME = lib.mkForce "/home/capcu";
        restartTriggers = [
          (pkgs.writeText "hermes-agent-gateway-config" (
            builtins.toJSON {
              inherit (config.services.hermes-agent) environment settings;
            }
          ))
        ];
        serviceConfig.TimeoutStopSec = 210;
      };

      systemd.services.hermes-webui = lib.mkIf secretsEnabled {
        after = [ "hermes-agent.service" ];
        requires = [ "hermes-agent.service" ];
      };

      systemd.services.tailscale-fortinet-trust = {
        description = "Trust the office FortiGate certificate presented for Headscale";
        wantedBy = [ "tailscaled.service" ];
        before = [ "tailscaled.service" ];
        after = [ "network-online.target" ];
        wants = [ "network-online.target" ];
        serviceConfig = {
          Type = "oneshot";
          StateDirectory = "tailscale-fortinet-trust";
        };
        script = "${lib.getExe trustFortinetHeadscaleCert} --no-restart";
      };

      systemd.services.tailscale-fortinet-trust-refresh = {
        description = "Refresh the office FortiGate certificate trusted by tailscaled";
        after = [ "network-online.target" ];
        wants = [ "network-online.target" ];
        serviceConfig = {
          Type = "oneshot";
          StateDirectory = "tailscale-fortinet-trust";
        };
        script = lib.getExe trustFortinetHeadscaleCert;
      };

      systemd.timers.tailscale-fortinet-trust-refresh = {
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnActiveSec = "30s";
          OnUnitActiveSec = "1h";
          AccuracySec = "10s";
        };
      };

      systemd.services.tailscaled = {
        after = [ "tailscale-fortinet-trust.service" ];
        wants = [ "tailscale-fortinet-trust.service" ];
        environment.SSL_CERT_FILE = fortinetHeadscaleBundle;
      };

      systemd.services.e1000e-offload-workaround = {
        description = "Disable e1000e transmit offloads that can wedge the I219-LM NIC";
        wantedBy = [ "multi-user.target" ];
        requires = [ "sys-subsystem-net-devices-enp128s31f6.device" ];
        after = [ "sys-subsystem-net-devices-enp128s31f6.device" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
        };
        script = "${pkgs.ethtool}/bin/ethtool --offload enp128s31f6 tso off gso off";
      };

      systemd.services.displaylink = {
        description = "DisplayLink Manager";
        wantedBy = [ "graphical.target" ];
        after = [ "display-manager.service" ];
        serviceConfig = {
          ExecStart = "${pkgs.displaylink}/bin/DisplayLinkManager";
          Restart = "on-failure";
          RestartSec = 5;
        };
      };

      programs.virt-manager.enable = true;

      virtualisation.libvirtd = {
        enable = true;
        qemu = {
          package = pkgs.qemu_kvm;
          swtpm.enable = true;
        };
      };

      systemd.services.libvirt-default-network = {
        description = "Start libvirt's default network";
        wantedBy = [ "multi-user.target" ];
        after = [ "libvirtd.service" ];
        requires = [ "libvirtd.service" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
        };
        script = ''
          ${pkgs.libvirt}/bin/virsh --connect qemu:///system net-autostart default
          ${pkgs.libvirt}/bin/virsh --connect qemu:///system net-start default || true
        '';
      };

      users.users.capcu.extraGroups = [
        "capcu"
        "libvirtd"
      ];

      home-manager.users.capcu.services.autorandr.extraOptions = [
        "--default"
        "capcuoffice"
      ];
      home-manager.users.capcu.xsession.initExtra = config.services.xserver.displayManager.setupCommands;
      home-manager.users.capcu.systemd.user.services.x0vncserver.Install.WantedBy = lib.mkForce [ ];

      environment.systemPackages = with pkgs; [
        displaylink
        llm-agents.packages.${stdenv.hostPlatform.system}.hermes-desktop
        virtio-win
      ];
    };

}
