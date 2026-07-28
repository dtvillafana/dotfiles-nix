{ self, ... }:
{
  flake.nixosModules.common =
    {
      config,
      lib,
      pkgs,
      nodename,
      ...
    }:
    let
      profileUsers = lib.filter (user: builtins.hasAttr user config.users.users) [
        "vir"
        "capcu"
      ];
    in
    {

      sops = {
        defaultSopsFile = self + /secrets/secrets.json;
        defaultSopsFormat = "json";
      }
      // lib.optionalAttrs (profileUsers != [ ]) {
        age.sshKeyPaths = map (user: "/home/${user}/.ssh/id_ed25519") profileUsers;
      };

      networking.hostName = nodename;

      services.resolved.enable = true;

      networking.networkmanager.enable = true;
      networking.firewall.allowedTCPPorts = [
        4095
        4096
      ];

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
        file
        git
        git-agecrypt
        gnupg
        neovim
        pavucontrol
        pinentry-tty
        unzip
        wget
        xdotool
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
