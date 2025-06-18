{config, pkgs, home-manager, ...}:
let
    external_git_repos = [
        {
            name = "nixvim";
            url = "https://dtvillafana:$(cat ${config.sops.secrets.git_github.path})@github.com/dtvillafana/nixvim";
            path = "$HOME/git-repos/nixvim";
        }
        {
            name = "nostr-playground";
            url = "https://dtvillafana:$(cat ${config.sops.secrets.git_github.path})@github.com/dtvillafana/nostr-playground";
            path = "$HOME/git-repos/nostr-playground";
        }
        {
            name = "orgfiles";
            url = "https://dvillafanaiv:$(cat ${config.sops.secrets.git_gitlab.path})@gitlab.com/personal2673713/org.git";
            path = "$HOME/git-repos/orgfiles";
        }
        {
            name = "homelab-nixos-generators";
            url = "https://dvillafanaiv:$(cat ${config.sops.secrets.git_gitlab.path})@gitlab.com/spectrum-it-solutions/nixos-generators.git";
            path = "$HOME/git-repos/homelab-nixos-generators";
        }
        {
            name = "stow-dotfiles";
            url = "vps:~/git-repos/dotfiles";
            path = "$HOME/git-repos/stow-dotfiles";
        }
    ];

    # Function to create a clone action for a Git forge repo
    make_git_forge_repo_action = repo: {
        name = "clone_${builtins.replaceStrings ["-"] ["_"] repo.name}";
        value = home-manager.lib.hm.dag.entryAfter ["writeBoundary"] ''
          if [ ! -d "${repo.path}" ]; then
              export GIT_SSH="${pkgs.openssh}/bin/ssh"
            ${pkgs.git}/bin/git clone ${repo.url} ${repo.path}
          else
              cd ${repo.path} && ${pkgs.git}/bin/git pull
          fi
        '';
    };

    external_git_actions = builtins.listToAttrs (map make_git_forge_repo_action external_git_repos);
in
    {
    home-manager.useGlobalPkgs = true;
    home-manager.useUserPackages = true;
    home-manager.backupFileExtension = "hm-bak";
    home-manager.users.vir = { pkgs, ... }: {
        # Home Manager needs a bit of information about you and the paths it should manage
        home.username = "vir";
        home.homeDirectory = "/home/vir";

        home.file.".xinitrc".text = ''
exec i3'';

        #         home.file.".gnupg/gpg-agent.conf".text = ''
        # enable-ssh-support
        # pinentry-program /run/current-system/sw/bin/pinentry
        #         '';

        # Allow unfree packages (if needed)
        nixpkgs.config.allowUnfree = true;

        # Let Home Manager install and manage itself
        programs.home-manager.enable = true;

        home.activation = external_git_actions;

        home.file = {
            ".ssh/config".text = ''
Host vps
    HostName 104.207.135.195
    IdentityFile ${config.sops.secrets.git_vps.path}
    User root
    port 4455'';
            ".local/share/gopass/stores/.keep" = {
                source = builtins.toFile "keep" "";
            };
        };

        # Packages that should be installed to the user profile
        home.packages = with pkgs; [
            age
            brave
            brightnessctl
            btop
            dunst
            feh
            fzf
            git
            gopass
            i3lock
            i3status
            jq
            lazygit
            libreoffice
            networkmanager
            nix-index
            pwgen-secure
            ripgrep
            rofi
            signal-desktop
            sops
            telegram-desktop
            vlc
            wireguard-tools
            xdotool
            xss-lock
            zathura
        ];

        # Terminal configuration - WezTerm (since you have it installed)
        programs.wezterm = {
            enable = true;
            extraConfig = ''
local wezterm = require 'wezterm'
-- This will hold the configuration.
local config = wezterm.config_builder()
config.use_fancy_tab_bar = false
config.show_tabs_in_tab_bar = false
config.show_new_tab_button_in_tab_bar = false
return config'';
            # Add custom configuration if needed
        };

        programs.rofi = {
            enable = true;
            terminal = "wezterm";
            theme = "Arc-Dark";
            font = "DejaVu Sans Mono 11";
            extraConfig = {
                modi = "run,drun";
                icon-theme = "Papirus";
                show-icons = true;
                drun-display-format = "{name} [<span weight='light' size='small'><i>({generic})</i></span>]";
                disable-history = false;
                hide-scrollbar = true;
            };
        };

        programs.i3status = {
            enable = true;
            general = {
                output_format = "i3bar";
                colors = true;
                interval = 5;
            };
            modules = {
                "ethernet eth0" = {
                    position = 1;
                    settings = {
                        format_up = "E: %ip (%speed)";
                        format_down = "E: down";
                    };
                };
                "wireless wlan0" = {
                    position = 2;
                    settings = {
                        format_up = "W: (%quality at %essid, %bitrate) %ip";
                        format_down = "W: down";
                    };
                };
                "disk /" = {
                    position = 3;
                    settings = {
                        format = "%free";
                    };
                };
                "battery 0" = {
                    position = 4;
                    settings = {
                        format = "%status %percentage %remaining %emptytime";
                        format_down = "";
                        status_chr = "⚡";
                        status_bat = "🔋";
                        status_unk = "";
                        status_full = "";
                        path = "/sys/class/power_supply/BAT%d/uevent";
                        low_threshold = 10;
                    };
                };
                "memory" = {
                    position = 5;
                    settings = {
                        format = "Tax Fraud Docs: %used";
                        threshold_degraded = "10%";
                        format_degraded = "COMMIT MORE TAX FRAUD: %free";
                    };
                };
                # "load" = {
                #     position = 6;
                #     settings = {
                #         format = "%5min";
                #     };
                # };
                "tztime local" = {
                    position = 7;
                    settings = {
                        format = "%Y-%m-%d %H:%M:%S";
                    };
                };
            };
        };

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
                    q = "exit";
                    lg = "lazygit";
                };
                initExtra = ''
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

        # Configure Git
        programs.git = {
            enable = true;
            userName = "David Villafaña"; # Replace with your name
            userEmail = "dvillafanaiv@proton.me"; # Replace with your email
            extraConfig = {
                core.sshCommand = "${pkgs.openssh}/bin/ssh";
                credential."https://github.com".helper = "store --file=${config.users.users.vir.home}/.git-credentials-github";
                credential."https://gitlab.com".helper = "store --file=${config.users.users.vir.home}/.git-credentials-gitlab";
                credential."https://bitbucket.org".helper = "store --file=${config.users.users.vir.home}/.git-credentials-bitbucket";
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
                    incdec_segments = ["path" "query"];
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

            quickmarks = {};
        };


        # Configure i3 with your custom config
        xsession.windowManager = {
            command = "exec i3";
            i3 = {
                enable = true;
                config = {
                    modifier = "Mod4"; # Windows/Super key
                    terminal = "wezterm"; # Your terminal of choice
                    fonts = {
                        names = [ "DejaVu Sans Mono" ];
                        style = "Normal";
                        size = 11.0;
                    };
                    bars = [
                        {
                            fonts = {
                                names = [ "DejaVu Sans Mono" "-misc-fixed-medium-r-normal--13-120-75-75-C-70-iso10646-1" ];
                                size = 11.0;
                            };
                            statusCommand = "i3status";
                        }
                    ];

                    window.commands = [
                        { criteria = { class = "qutebrowser"; instance = "qutebrowser"; }; command = "move to workspace $web"; }
                        { criteria = { class = "Brave-browser"; }; command = "move to workspace $web"; }
                        { criteria = { class = "brave-browser"; }; command = "move to workspace $web"; }
                        { criteria = { class = "org.wezfurlong.wezterm"; }; command = "move to workspace $terms"; }
                        { criteria = { class = "wezterm"; }; command = "move to workspace $terms"; }
                        { criteria = { class = "vlc"; }; command = "move to workspace $media"; }
                        { criteria = { class = "Signal"; }; command = "move to workspace $comms"; }
                        { criteria = { class = "TelegramDesktop"; }; command = "move to workspace $comms"; }
                        { criteria = { class = "Zathura"; }; command = "move to workspace $docs"; }
                        { criteria = { class = "libreoffice"; }; command = "move to workspace $docs"; }
                        { criteria = { class = "sqlitebrowser"; }; command = "move to workspace $DB"; }
                        { criteria = { class = "DB Browser for SQLite"; }; command = "move to workspace $DB"; }
                        { criteria = { class = "Microsoft Teams - Preview"; }; command = "move to workspace $comms"; }
                        { criteria = { class = "Virt-manager"; }; command = "move to workspace $VMs"; }
                    ];

                    floating.modifier = "Mod4";
                    focus.mouseWarping = false;
                    workspaceAutoBackAndForth = true;

                    modes = {
                        resize = {
                            "h" = "resize shrink width 10 px or 10 ppt";
                            "j" = "resize grow height 10 px or 10 ppt";
                            "k" = "resize shrink height 10 px or 10 ppt";
                            "l" = "resize grow width 10 px or 10 ppt";
                            "Left" = "resize shrink width 10 px or 10 ppt";
                            "Down" = "resize grow height 10 px or 10 ppt";
                            "Up" = "resize shrink height 10 px or 10 ppt";
                            "Right" = "resize grow width 10 px or 10 ppt";
                            "Return" = "mode default";
                            "Escape" = "mode default";
                            "$mod+r" = "mode default";
                        };
                        "$mode_system" = {
                            "l" = "exec --no-startup-id i3lock -c 000000, mode default";
                            "e" = "exec --no-startup-id i3-msg exit, mode default";
                            "Ctrl+s" = "exec --no-startup-id $i3lockwall && sudo suspend, mode default";
                            "h" = "exec --no-startup-id $i3lockwall && sudo hibernate, mode default";
                            "r" = "exec --no-startup-id sudo reboot, mode default";
                            "s" = "exec --no-startup-id sudo poweroff, mode default";
                            "Return" = "mode default";
                            "Escape" = "mode default";
                        };
                        "$mode_i3bar" = {
                            "$mod+h" = "exec i3-msg bar mode hide";
                            "$mod+Shift+h" = "exec i3-msg bar mode dock";
                            "Escape" = "mode default";
                        };
                        "$mouseMover" = {
                            "c" = "mode default";
                            "Escape" = "mode default";
                            "space" = "exec xdotool click 1 ; mode default";
                            "enter" = "exec xdotool click 1 ; mode default";
                            "i" = "exec xdotool click 1";
                            "shift+space" = "exec xdotool click 3";
                            "shift+i" = "exec xdotool click 3";
                            "o" = "exec xdotool click 4";
                            "p" = "exec xdotool click 5";
                            "h" = "exec xdotool mousemove_relative -- -200 0";
                            "j" = "exec xdotool mousemove_relative 0 200";
                            "k" = "exec xdotool mousemove_relative 0 -200";
                            "l" = "exec xdotool mousemove_relative 200 0";
                            "shift+h" = "exec xdotool mousemove_relative -- -18 0";
                            "shift+j" = "exec xdotool mousemove_relative 0 18";
                            "shift+k" = "exec xdotool mousemove_relative 0 -18";
                            "shift+l" = "exec xdotool mousemove_relative 18 0";
                        };
                        "$mode_workspaces" = {
                            "l" = "move workspace to output right";
                            "h" = "move workspace to output left";
                            "Return" = "mode default";
                            "Escape" = "mode default";
                        };
                    };

                    keybindings = let
                        mod = "Mod4";
                        mode_system = "System (l) lock, (e) logout, (s) shutdown, (h) hibernate, (r) reboot, (CTRL+s) suspend";
                        mouseMover = "Mouse movement : quit(c)|move(hjkl)|move less(shift+hjkl)|click(i)|click&exit(spacebar/enter)|right click(shift+spacebar/I)|scroll(o/p)";
                        mode_i3bar = "i3bar: hide (mod+h) unhide (mod+shift+h)";
                        mode_workspaces = "(h) move workspace left, (l) move workspace right";
                        refresh_i3status = "killall -SIGUSR1 i3status";
                        terms = "terminals";
                        web = "web";
                        docs = "documents";
                        media = "media";
                        comms = "comms";
                        VMs = "VMs";
                        DB = "DB";
                        ssh = "SSH";
                        misc = "misc";
                        termsbk = "Background Processes";
                    in {
                        "${mod}+Return" = "exec wezterm";
                        "${mod}+Shift+t" = "exec i3-sensible-terminal";
                        "${mod}+Shift+q" = "kill";
                        "${mod}+d" = "exec rofi -show drun";
                        "${mod}+g" = "exec gopass ls --flat | rofi -dmenu | xargs --no-run-if-empty gopass show -o | xdotool type --clearmodifiers --file -";
                        "${mod}+minus" = "exec --no-startup-id brightnessctl set 5%- && notify-send -t 300 \"`brightnessctl | grep -E '[0-9]{2}%' `\"";
                        "${mod}+plus" = "exec --no-startup-id brightnessctl set +5% && notify-send -t 300 \"`brightnessctl | grep -E '[0-9]{2}%' `\"";
                        "${mod}+p" = "exec xinput --disable \"$(xinput | awk -F = '/TouchPad/{print $2}' | cut -b 1-2)\"";
                        "${mod}+Shift+p" = "exec xinput --enable \"$(xinput | awk -F = '/TouchPad/{print $2}' | cut -b 1-2)\"";
                        "${mod}+h" = "focus left";
                        "${mod}+j" = "focus down";
                        "${mod}+k" = "focus up";
                        "${mod}+l" = "focus right";
                        "${mod}+Left" = "focus left";
                        "${mod}+Down" = "focus down";
                        "${mod}+Up" = "focus up";
                        "${mod}+Right" = "focus right";
                        "${mod}+Shift+h" = "move left";
                        "${mod}+Shift+j" = "move down";
                        "${mod}+Shift+k" = "move up";
                        "${mod}+Shift+l" = "move right";
                        "${mod}+Shift+Left" = "move left";
                        "${mod}+Shift+Down" = "move down";
                        "${mod}+Shift+Up" = "move up";
                        "${mod}+Shift+Right" = "move right";
                        "${mod}+b" = "split h";
                        "${mod}+v" = "split v";
                        "${mod}+f" = "fullscreen toggle";
                        "${mod}+s" = "layout stacking";
                        "${mod}+w" = "layout tabbed";
                        "${mod}+e" = "layout toggle split";
                        "${mod}+Shift+space" = "floating toggle";
                        "${mod}+space" = "focus mode_toggle";
                        "${mod}+a" = "focus parent";
                        "${mod}+BackSpace" = "mode \"${mode_system}\"";
                        "${mod}+i" = "mode \"${mode_i3bar}\"";
                        "${mod}+c" = "mode \"${mouseMover}\"";
                        "${mod}+m" = "mode \"${mode_workspaces}\"";
                        "${mod}+1" = "workspace ${terms}";
                        "${mod}+2" = "workspace ${web}";
                        "${mod}+3" = "workspace ${docs}";
                        "${mod}+4" = "workspace ${media}";
                        "${mod}+5" = "workspace ${comms}";
                        "${mod}+6" = "workspace ${VMs}";
                        "${mod}+7" = "workspace ${DB}";
                        "${mod}+8" = "workspace ${ssh}";
                        "${mod}+9" = "workspace ${misc}";
                        "${mod}+0" = "workspace ${termsbk}";
                        "${mod}+Shift+1" = "move container to workspace ${terms}";
                        "${mod}+Shift+2" = "move container to workspace ${web}";
                        "${mod}+Shift+3" = "move container to workspace ${docs}";
                        "${mod}+Shift+4" = "move container to workspace ${media}";
                        "${mod}+Shift+5" = "move container to workspace ${comms}";
                        "${mod}+Shift+6" = "move container to workspace ${VMs}";
                        "${mod}+Shift+7" = "move container to workspace ${DB}";
                        "${mod}+Shift+8" = "move container to workspace ${ssh}";
                        "${mod}+Shift+9" = "move container to workspace ${misc}";
                        "${mod}+Shift+0" = "move container to workspace ${termsbk}";
                        "${mod}+Shift+c" = "reload";
                        "${mod}+Shift+r" = "restart";
                        "${mod}+Shift+e" = "exec i3-nagbar -t warning -m 'You pressed the exit shortcut. Do you really want to exit i3? This will end your X session.' -B 'Yes, exit i3' 'i3-msg exit'";
                        "${mod}+r" = "mode resize";
                        "XF86AudioRaiseVolume" = "exec --no-startup-id pactl set-sink-volume @DEFAULT_SINK@ +10% && ${refresh_i3status}";
                        "XF86AudioLowerVolume" = "exec --no-startup-id pactl set-sink-volume @DEFAULT_SINK@ -10% && ${refresh_i3status}";
                        "XF86AudioMute" = "exec --no-startup-id pactl set-sink-mute @DEFAULT_SINK@ toggle && ${refresh_i3status}";
                        "XF86AudioMicMute" = "exec --no-startup-id pactl set-source-mute @DEFAULT_SOURCE@ toggle && ${refresh_i3status}";
                    };

                    startup = [
                        { command = "--no-startup-id xss-lock --transfer-sleep-lock -- i3lock --nofork"; }
                        { command = "--no-startup-id nm-applet"; }
                        { command = "dunst &"; }
                        { command = "--no-startup-id feh --no-fehbg --bg-fill '~/pictures/wallpaper.jpg'"; }
                    ];
                };
                extraConfig = ''
# Define workspace variables
set $terms "terminals"
set $web "web"
set $docs "documents"
set $media "media"
set $comms "comms"
set $VMs "VMs"
set $DB "DB"
set $ssh "SSH"
set $misc "misc"
set $termsbk "Background Processes"

# Define mode variables
set $mode_system System (l) lock, (e) logout, (s) shutdown, (h) hibernate, (r) reboot, (CTRL+s) suspend
set $mode_i3bar i3bar: hide (mod+h) unhide (mod+shift+h)
set $mouseMover Mouse movement : quit(c)|move(hjkl)|move less(shift+hjkl)|click(i)|click&exit(spacebar/enter)|right click(shift+spacebar/I)|scroll(o/p)
set $mode_workspaces (h) move workspace left, (l) move workspace right

# Define i3status refresh command
set $refresh_i3status killall -SIGUSR1 i3status
                '';
            };
        };

        # This value determines the Home Manager release that your
        # configuration is compatible with. This helps avoid breakage
        # when a new Home Manager release introduces backwards
        # incompatible changes.
        home.stateVersion = "24.05";
    };
}
