{ self, ... }:
{
  flake.nixosModules.baseSystem =
    { pkgs, nodename, ... }:
    {
      networking.hostName = nodename;
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

      documentation.nixos.enable = false;
      home-manager.sharedModules = [
        {
          manual.manpages.enable = false;
          manual.json.enable = false;
        }
      ];

      security.sudo.wheelNeedsPassword = false;
      programs.nix-ld.enable = true;
      programs.gnupg.agent = {
        enable = true;
        enableSSHSupport = true;
      };
      programs.zsh.enable = true;
      services.openssh.enable = true;

      environment.systemPackages = with pkgs; [
        curl
        self.packages.${pkgs.stdenv.hostPlatform.system}.excise
        file
        gh
        git
        git-agecrypt
        gnupg
        neovim
        self.packages.${pkgs.stdenv.hostPlatform.system}.open-browser-use
        pinentry-tty
        ssh-to-age
        unzip
        wget
      ];

      system.stateVersion = "24.11";
    };
}
