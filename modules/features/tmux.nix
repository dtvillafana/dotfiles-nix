{ self, inputs, ... }:
{
  flake.nixosModules.tmux =
    { ... }:
    {
      home-manager.users.vir =
        { pkgs, ... }:
        {
          programs.tmux = {
            enable = true;
            extraConfig = ''
              set -g set-clipboard on
              set -g status off
              set -g default-terminal "screen-256color"
              set -ga terminal-overrides ",*256col*:Tc"
              set -ga update-environment "KITTY_WINDOW_ID KITTY_LISTEN_ON"
              set -sg escape-time 0
              set -g allow-passthrough on
              unbind s
              bind C-s display-popup -E -w 80% -h 80% "\
                  tmux list-sessions -F '#{session_attached} #{session_name}' |\
                  sort |\
                  awk '{print \$2}' |\
                  fzf --reverse --header jump-to-session --preview 'tmux capture-pane -pt {}' --bind 'focus:refresh-preview,ctrl-r:refresh-preview,ctrl-d:execute(tmux kill-session -t {})+abort' |\
                  xargs tmux switch-client -t"
            '';
          };
        };
    };
}
