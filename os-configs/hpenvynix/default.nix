{
  config,
  pkgs,
  home-manager,
  nodename,
  nixvim,
  system,
  lib,
  opencode-tui,
  codex-cli,
  claude-code,
  ...
}:
{
  services.xserver.windowManager.i3 = {
    extraPackages = with pkgs; [
      # enable wifi drivers
      linuxKernel.packages.linux_hardened.broadcom_sta
    ];
  };

  services.desktopManager.plasma6.enable = true;

  users.users.gabe = {
    isNormalUser = true;
    description = "gabe";
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
  users.groups.gabe = { };

  home-manager.users.gabe =
    { pkgs, ... }:
    {
      # Home Manager needs a bit of information about you and the paths it should manage
      home.username = "gabe";
      home.homeDirectory = "/home/gabe";
      home.sessionPath = [
        "$HOME/.nix-profile/bin"
        "/etc/profiles/per-user/gabe/bin"
        "/run/wrappers/bin"
        "/run/current-system/sw/bin"
      ];

      #         home.file.".gnupg/gpg-agent.conf".text = ''
      # enable-ssh-support
      # pinentry-program /run/current-system/sw/bin/pinentry
      #         '';

      # Allow unfree packages (if needed)
      nixpkgs.config.allowUnfree = true;

      # Let Home Manager install and manage itself
      programs.home-manager.enable = true;

      programs.chromium = {
        enable = true;
        package = pkgs.brave;
        commandLineArgs = [ "--password-store=basic" ];
        extensions = [
          { id = "dbepggeogbaibhgnhhndojpepiihcmeb"; } # vimium - currently not working
        ];
      };

      programs.tmux = {
        enable = true;
        extraConfig = ''
          set -g set-clipboard on
          set -g status off
          set -g default-terminal "screen-256color"
          set -ga terminal-overrides ",*256col*:Tc"
          set -sg escape-time 0
          set -g allow-passthrough on
          unbind s
          bind C-s display-popup -E -w 80% -h 80% "\
              tmux list-sessions -F '#{?session_attached,,#{session_name}}' |\
              sed '/^$/d' |\
              fzf --reverse --header jump-to-session --preview 'tmux capture-pane -pt {}' |\
              xargs tmux switch-client -t"
        '';
      };


      programs = {
        ghostty = {
          enable = true;
          settings = {
            window-decoration = "none";
            gtk-titlebar = false;
            keybind = [
              "ctrl+enter=unbind"
            ];
          };
        };
      };

      # Packages that should be installed to the user profile
      home.packages = with pkgs; [
        age
        arandr
        audacity
        bc
        blueman
        brightnessctl
        btop
        pkgs.claude-code
        codex-cli.packages.${system}.default
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
        opencode-tui.packages.${system}.default
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

      programs = {
        direnv = {
          enable = true;
          enableZshIntegration = true; # see note on other shells below
          nix-direnv.enable = true;
        };

        zsh = {
          enable = true; # see note on other shells below
          plugins = [
            {
              name = "powerlevel10k";
              src = pkgs.zsh-powerlevel10k;
              file = "share/zsh-powerlevel10k/powerlevel10k.zsh-theme";
            }
          ];
          syntaxHighlighting.enable = true;
          enableCompletion = true;
          autocd = false;
          autosuggestion.enable = true;
          oh-my-zsh = {
            enable = true;
            plugins = [
              "git"
              "direnv"
            ];
          };
          shellAliases = {
            nv = lib.getExe nixvim.packages.${system}.default;
            nvd = "nix run $HOME/git-repos/nixvim";
            q = "exit";
            lg = "lazygit";
            nr = ''nix flake update --flake "path:/home/gabe/git-repos/dotfiles-nix" nixvim && sudo nixos-rebuild switch --flake "path:/home/gabe/git-repos/dotfiles-nix#${nodename}"'';
            nrf = ''nix flake update --flake "path:/home/gabe/git-repos/dotfiles-nix" && sudo nixos-rebuild switch --flake "path:/home/gabe/git-repos/dotfiles-nix#${nodename}" --refresh'';
          };
          profileExtra = ''
            if [[ -z $DISPLAY && $TTY == /dev/tty[0-9] ]]; then
              exec startx
            fi
          '';
          initContent = ''
            # Enable Powerlevel10k instant prompt
            if [[ -r "''${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-''${(%):-%n}.zsh" ]]; then
              source "''${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-''${(%):-%n}.zsh"
            fi

            # To customize prompt, run `p10k configure` or edit ~/.p10k.zsh
            [[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
            export EDITOR="nvim";
          '';
        };
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

      programs.qutebrowser = {
        enable = true;

        loadAutoconfig = false;

        keyBindings = {
          normal = {
            P = "hint links run :open -p {hint-url}";
            d = null;
            D = null;
          };
        };

        extraConfig = ''
          # Per-domain content settings
          config.set('content.cookies.accept', 'all', 'chrome-devtools://*')
          config.set('content.cookies.accept', 'all', 'devtools://*')

          config.set('content.headers.user_agent', 'Mozilla/5.0 ({os_info}) AppleWebKit/{webkit_version} (KHTML, like Gecko) {upstream_browser_key}/{upstream_browser_version} Safari/{webkit_version}', 'https://web.whatsapp.com/')
          config.set('content.headers.user_agent', 'Mozilla/5.0 ({os_info}; rv:90.0) Gecko/20100101 Firefox/90.0', 'https://accounts.google.com/*')
          config.set('content.headers.user_agent', 'Mozilla/5.0 ({os_info}) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/99 Safari/537.36', 'https://*.slack.com/*')

          config.set('content.images', True, 'chrome-devtools://*')
          config.set('content.images', True, 'devtools://*')

          config.set('content.javascript.enabled', True, 'chrome-devtools://*')
          config.set('content.javascript.enabled', True, 'devtools://*')
          config.set('content.javascript.enabled', True, 'chrome://*/*')
          config.set('content.javascript.enabled', True, 'qute://*/*')

          c.fileselect.handler = 'external'
          c.fileselect.single_file.command = ['${pkgs.zenity}/bin/zenity', '--file-selection']
          c.fileselect.folder.command = ['${pkgs.zenity}/bin/zenity', '--file-selection', '--directory']
          c.fileselect.multiple_files.command = ['sh', '-c', '${pkgs.zenity}/bin/zenity --file-selection --multiple | tr "|" "\\n"']
        '';

        aliases = {
          w = "session-save";
          q = "close";
          qa = "quit";
          wq = "quit --save";
          wqa = "quit --save";
          Wq = "quit --save";
          WQ = "quit --save";
          wQ = "quit --save";
        };

        settings = {
          content = {
            autoplay = false;
            images = true;

            # Cookie settings
            cookies.accept = "all";

            # JavaScript settings
            javascript.enabled = true;

            # Header settings
            headers.accept_language = "";
            headers.user_agent = "Mozilla/5.0 ({os_info}) AppleWebKit/{webkit_version} (KHTML, like Gecko) {upstream_browser_key}/{upstream_browser_version} Safari/{webkit_version}";
          };

          tabs = {
            last_close = "close";
            position = "bottom";
            show = "switching";
            show_switching_delay = 2000;
          };

          url = {
            default_page = "https://search.brave.com";
            incdec_segments = [
              "path"
              "query"
            ];
            start_pages = "https://search.brave.com";
          };

          colors = {
            webpage = {
              preferred_color_scheme = "dark";
            };

            hints = {
              fg = "chartreuse";
              bg = "qlineargradient(x1:0, y1:0, x2:0, y2:1, stop:0 rgba(255, 0, 0, 0.8), stop:1 rgba(255, 0, 0, 0.8))";
            };
          };
        };

        searchEngines = {
          DEFAULT = "https://search.brave.com/search?q={}&source=web";
        };

        quickmarks = { };
      };

      xsession = {
        enable = true;
        scriptPath = ".xinitrc";
        windowManager.command = "exec startplasma-x11";
      };

      # This value determines the Home Manager release that your
      # configuration is compatible with. This helps avoid breakage
      # when a new Home Manager release introduces backwards
      # incompatible changes.
      home.stateVersion = "25.11";
    };
}
