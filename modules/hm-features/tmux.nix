{ ... }:
{
  flake.homeModules.tmux =
    { ... }:
    {
      programs.tmux = {
        enable = true;
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
