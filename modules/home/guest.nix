{ self, ... }:
{
  flake.nixosModules.guestHome =
    { pkgs, ... }:
    {
      users.users.guest = {
        isNormalUser = true;
        description = "guest";
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
      users.groups.guest = { };

      services.desktopManager.plasma6.enable = true;
      home-manager.users.guest =
        { pkgs, ... }:
        {
          imports = [
            self.homeModules.browsers
            self.homeModules.zathura
          ];

          home.username = "guest";
          home.homeDirectory = "/home/guest";
          home.sessionPath = [
            "$HOME/.nix-profile/bin"
            "/etc/profiles/per-user/guest/bin"
            "/run/wrappers/bin"
            "/run/current-system/sw/bin"
          ];

          nixpkgs.config.allowUnfree = true;

          programs.home-manager.enable = true;

          programs.ghostty = {
            enable = true;
            settings = {
              window-decoration = "none";
              gtk-titlebar = false;
              keybind = [
                "ctrl+enter=unbind"
              ];
            };
          };

          home.packages = with pkgs; [
            age
            arandr
            audacity
            bc
            blueman
            brightnessctl
            btop
            fd
            fzf
            gemini-cli
            git
            gopass
            jq
            lazygit
            libreoffice
            networkmanager
            nix-index
            pwgen-secure
            python313FreeThreading
            ripgrep
            signal-desktop
            sops
            telegram-desktop
            vlc
            wireguard-tools
            xdotool
            xournalpp
            zathura
            zbar
            zenity
            zip
          ];

          programs.direnv = {
            enable = true;
            enableZshIntegration = true;
            nix-direnv.enable = true;
          };

          programs.zsh = {
            enable = true;
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

          xsession = {
            enable = true;
            scriptPath = ".xinitrc";
            windowManager.command = "exec startplasma-x11";
          };

          home.stateVersion = "25.11";
        };
    };
}
