{ self, ... }:
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
        defaultSopsFile = self + /secrets/secrets.json;
        defaultSopsFormat = "json";
        age.keyFile = "/home/vir/.config/sops/age/keys.txt";
        secrets = {
          "git_github" = {
            owner = config.users.users.vir.name;
          };
          "git_gitlab" = {
            owner = config.users.users.vir.name;
          };
          "git_gitlab_pat" = {
            owner = config.users.users.vir.name;
          };
          "git_vps" = {
            owner = config.users.users.vir.name;
          };
          "ssh_nix_key" = {
            owner = config.users.users.vir.name;
          };
          "hermes-env" = {
            sopsFile = self + /secrets/hermes.yaml;
            format = "yaml";
            owner = "vir";
            group = "vir";
          };
        };
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
        max-jobs = 10;
        cores = 1;
        auto-optimise-store = true;
        http-connections = 50;
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
