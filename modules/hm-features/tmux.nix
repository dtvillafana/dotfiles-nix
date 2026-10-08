{ ... }:
{
  flake.homeModules.tmux =
    { ... }:
    {
      programs.tmux = {
        enable = true;
        keyMode = "vi";
        extraConfig = ''
          set -g set-clipboard on
          set -g status off
          set -g default-terminal "screen-256color"
          set -ga terminal-overrides ",*256col*:Tc"
          # DISPLAY is forwarded by default, so on Xorg Neovim's xclip reached the
          # system clipboard. On Hyprland the clipboard is WAYLAND_DISPLAY; without
          # it Neovim still sees DISPLAY=:0 and writes an XWayland selection that
          # Hyprland does not publish.
          set -ga update-environment "KITTY_WINDOW_ID KITTY_LISTEN_ON WAYLAND_DISPLAY"
          set -sg escape-time 0
          set -g allow-passthrough on

          # Use Vim directions, retaining the default modifiers and repeatability.
          unbind Left
          unbind Down
          unbind Up
          unbind Right
          bind -r h select-pane -L
          bind -r j select-pane -D
          bind -r k select-pane -U
          bind -r l select-pane -R

          unbind M-Left
          unbind M-Down
          unbind M-Up
          unbind M-Right
          bind -r M-h resize-pane -L 5
          bind -r M-j resize-pane -D 5
          bind -r M-k resize-pane -U 5
          bind -r M-l resize-pane -R 5

          unbind C-Left
          unbind C-Down
          unbind C-Up
          unbind C-Right
          bind -r C-h resize-pane -L
          bind -r C-j resize-pane -D
          bind -r C-k resize-pane -U
          bind -r C-l resize-pane -R

          unbind S-Left
          unbind S-Down
          unbind S-Up
          unbind S-Right
          bind -r H refresh-client -L 10
          bind -r J refresh-client -D 10
          bind -r K refresh-client -U 10
          bind -r L refresh-client -R 10

          # Replace arrows in both copy-mode tables; vi mode already has hjkl.
          unbind -T copy-mode Left
          unbind -T copy-mode Down
          unbind -T copy-mode Up
          unbind -T copy-mode Right
          bind -T copy-mode h send-keys -X cursor-left
          bind -T copy-mode j send-keys -X cursor-down
          bind -T copy-mode k send-keys -X cursor-up
          bind -T copy-mode l send-keys -X cursor-right
          unbind -T copy-mode M-Down
          unbind -T copy-mode M-Up
          bind -T copy-mode M-j send-keys -X halfpage-down
          bind -T copy-mode M-k send-keys -X halfpage-up
          unbind -T copy-mode C-Down
          unbind -T copy-mode C-Up
          bind -T copy-mode C-j send-keys -X scroll-down
          bind -T copy-mode C-k send-keys -X scroll-up

          unbind -T copy-mode-vi Left
          unbind -T copy-mode-vi Down
          unbind -T copy-mode-vi Up
          unbind -T copy-mode-vi Right
          unbind -T copy-mode-vi C-Down
          unbind -T copy-mode-vi C-Up
          bind -T copy-mode-vi C-j send-keys -X scroll-down
          bind -T copy-mode-vi C-k send-keys -X scroll-up

          unbind s
          bind C-s display-popup -E -w 80% -h 80% "\
              tmux list-sessions -F '#{session_attached} #{session_name}' |\
              sort |\
              awk '{print \$2}' |\
              fzf --reverse --header jump-to-session --preview 'tmux capture-pane -p -t {} -S -200' --preview-window 'down,60%,wrap,follow' --bind 'focus:refresh-preview,ctrl-r:refresh-preview,ctrl-d:execute(tmux kill-session -t {})+abort' |\
              xargs tmux switch-client -t"
        '';
      };
    };
}
