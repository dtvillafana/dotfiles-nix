{ ... }:
{
  flake.nixosModules.capcuDellConfig =
    {
      config,
      llm-agents,
      lib,
      pkgs,
      ...
    }:
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
        kernelPackages = pkgs.linuxPackages_latest;
        crashDump.enable = true;
        extraModulePackages = [ config.boot.kernelPackages.evdi ];
        kernelModules = [ "evdi" ];
      };

      services.fwupd.enable = true;
      services.udev.packages = [ pkgs.displaylink ];

      nixpkgs.config.cudaCapabilities = [ "12.0" ];
      services.ollama.loadModels = lib.mkForce [ "gpt-oss:20b" ];

      services.hermes-agent = {
        enable = true;
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
        settings = {
          toolsets = [ "all" ];
          model = {
            provider = "custom";
            base_url = "http://127.0.0.1:11434/v1";
            default = "gpt-oss:20b";
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

      systemd.services.hermes-agent = {
        after = [ "ollama-model-loader.service" ];
        requires = [ "ollama-model-loader.service" ];
        environment.HOME = lib.mkForce "/home/capcu";
        serviceConfig.TimeoutStopSec = 210;
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

      users.users.capcu.extraGroups = [ "libvirtd" ];

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

  flake.nixosModules.capcuDellBootstrapConfig =
    { pkgs, ... }:
    {
      users.users.bootstrap = {
        initialHashedPassword = "$y$j9T$qTtCIlz3KyW/1WKELiesF0$7nCjPFCkT8Ww04ieHzXVW8sJ2LZhL04fnENrTiP6s.C";
        isNormalUser = true;
        description = "bootstrap";
        extraGroups = [
          "networkmanager"
          "wheel"
          "dialout"
          "tty"
        ];
        packages = with pkgs; [
          curl
          git
          neovim
        ];
        shell = pkgs.zsh;
      };
      users.groups.bootstrap = { };
    };
}
