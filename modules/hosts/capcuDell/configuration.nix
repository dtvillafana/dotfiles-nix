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
      # Office FortiGate FG100FTK22020085 MITMs Headscale. Trust that CA only
      # inside tailscaled so the rest of the system keeps the public roots.
      tailscaleCaBundle = pkgs.runCommand "tailscale-ca-bundle.crt" { } ''
        cat ${config.security.pki.caBundle} ${./Fortinet_CA_SSL.cer} >"$out"
      '';
      # Run a minimal Hyprland greeter so WayVNC also works before login.
      # Its server exits with the greeter; capcu's user service takes over 5901.
      greeterConfig = ''
        hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 })
        -- Reuse desktop options and host overrides, not shortcuts or session startup.
        hl.config(${
          lib.generators.toLua { }
            config.home-manager.users.capcu.wayland.windowManager.hyprland.settings.config
        })
        hl.on("hyprland.start", function()
          hl.exec_cmd("${lib.getExe greeterVnc}")
        end)
      '';
      greeterVncConfig = pkgs.writeText "greeter-wayvnc.conf" ''
        address=127.0.0.1 ::1
        port=5901
        enable_auth=false
      '';
      greeterVnc = pkgs.writeShellApplication {
        name = "greeter-wayvnc";
        runtimeInputs = [
          pkgs.coreutils
          pkgs.wayvnc
        ];
        text = ''
          # On logout, the old user server may briefly still own port 5901.
          # Retry while the greeter compositor is alive, never after it exits.
          while [ -S "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY" ]; do
            wayvnc --desktop --disable-resizing --config ${greeterVncConfig} || true
            sleep 2
          done
        '';
      };
    in
    {
      services.xserver.videoDrivers = [ "nvidia" ];

      services.displayManager = {
        dms-greeter = {
          enable = true;
          compositor = {
            name = "hyprland";
            customConfig = greeterConfig;
          };
          # Keep the stock login/authentication flow, adding the lock screen's
          # failure animation and Lua support for this host's Hyprland version.
          package = pkgs.dms-shell.overrideAttrs (old: {
            # Patch src itself: dms-shell installs QML directly from src.
            src = pkgs.applyPatches {
              src = old.src;
              patches = [ ../../../packages/dms-greeter-capcuDell.patch ];
            };
          });
        };
        defaultSession = "hyprland-uwsm";
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
            # XRandR reverse PRIME is X11-only. Hyprland handles DRM outputs.
            offload.enable = true;
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

      # Idle input is reported by Hyprland. loginctl runs hypridle's lock_cmd.
      home-manager.users.capcu.services.hypridle.settings.listener = [
        {
          timeout = 600;
          on-timeout = "loginctl lock-session";
        }
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

      # Temporary: the office firewall blocks Headscale. LAN SSH/VNC stays usable.
      # Remove this override to re-enable this host without changing other nodes.
      services.tailscale.enable = lib.mkForce false;
      systemd.services.tailscaled = lib.mkIf config.services.tailscale.enable {
        environment.SSL_CERT_FILE = "${tailscaleCaBundle}";
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

      # spice-gtk sends evdev scancodes, so Hyprland's ctrl:swapcaps never
      # reaches a VM console from a keyboard plugged into this machine.
      # Swap Caps Lock and Left Ctrl in the kernel, and do not also set that
      # XKB option here or the desktop would swap twice. Remmina is unchanged:
      # the VNC client applies its own swap and sends keysyms, which skip hwdb.
      services.udev.extraHwdb = ''
        evdev:atkbd:*
          KEYBOARD_KEY_3a=leftctrl
          KEYBOARD_KEY_1d=capslock

        evdev:input:b0003v*p*
          KEYBOARD_KEY_70039=leftctrl
          KEYBOARD_KEY_700e0=capslock

        evdev:input:b0005v*p*
          KEYBOARD_KEY_70039=leftctrl
          KEYBOARD_KEY_700e0=capslock

        evdev:input:b0018v*p*
          KEYBOARD_KEY_70039=leftctrl
          KEYBOARD_KEY_700e0=capslock
      '';
      services.xserver.xkb.options = lib.mkForce "";
      home-manager.users.capcu.wayland.windowManager.hyprland.settings.config.input.kb_options =
        lib.mkForce "";

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

      environment.systemPackages = with pkgs; [
        displaylink
        llm-agents.packages.${stdenv.hostPlatform.system}.hermes-desktop
        virtio-win
      ];
    };

}
