{ ... }:
{
  flake.nixosModules.capcuDellConfig =
    {
      config,
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
        extraModulePackages = [ config.boot.kernelPackages.evdi ];
        kernelModules = [ "evdi" ];
      };

      services.udev.packages = [ pkgs.displaylink ];

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
