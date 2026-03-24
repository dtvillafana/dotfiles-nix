{ self, inputs, ... }:
{
  flake.nixosModules.common =
    {
      config,
      pkgs,
      nodename,
      ...
    }:
    {

      sops = {
        defaultSopsFile = "${self}/secrets/secrets.json";
        defaultSopsFormat = "json";
        age.keyFile = "/home/vir/.config/sops/age/keys.txt";
        secrets = {
          "git_github" = {
            owner = config.users.users.vir.name;
          };
          "git_gitlab" = {
            owner = config.users.users.vir.name;
          };
          "git_vps" = {
            owner = config.users.users.vir.name;
          };
          "ssh_nix_key" = {
            owner = config.users.users.vir.name;
          };
        };
      };

      networking.hostName = nodename;

      services.resolved.enable = true;

      networking.networkmanager.enable = true;

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

      services.xserver = {
        enable = true;

        displayManager.startx.enable = true;

        desktopManager.xterm.enable = false;

        windowManager.i3 = {
          enable = true;
          extraPackages = with pkgs; [
            dmenu
            dunst
            i3status
            i3lock
            i3blocks
          ];
        };

        xkb = {
          layout = "us";
          options = "ctrl:swapcaps";
        };
      };

      services.printing.enable = true;

      services.pulseaudio.enable = false;
      security.rtkit.enable = true;
      services.pipewire = {
        enable = true;
        alsa.enable = true;
        alsa.support32Bit = true;
        pulse.enable = true;
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

      security.sudo.wheelNeedsPassword = false;

      nixpkgs.config = {
        allowUnfree = true;
      };

      nix.settings.experimental-features = [
        "nix-command"
        "flakes"
      ];

      nix.gc = {
        automatic = true;
        dates = "weekly";
        options = "--delete-older-than 30d";
      };

      environment.systemPackages = with pkgs; [
        neovim
        wget
        curl
        git
        pavucontrol
        pinentry-tty
        gnupg
        file
        xdotool
        unzip
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
