{ self, inputs, ... }:
{
  flake.nixosModules.zsh =
    {
      pkgs,
      lib,
      nixvim,
      system,
      nodename,
      ...
    }:
    {
      home-manager.users.vir =
        { pkgs, ... }:
        {
          programs = {
            direnv = {
              enable = true;
              enableZshIntegration = true;
              nix-direnv.enable = true;
            };

            nix-index = {
              enable = true;
              enableZshIntegration = true;
            };

            zsh = {
              enable = true;
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
              sessionVariables = {
                EDITOR = lib.getExe pkgs.neovim;
              };
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
                nr = ''nix flake update --flake "path:/home/vir/git-repos/dotfiles-nix" nixvim && sudo nixos-rebuild switch --flake "path:/home/vir/git-repos/dotfiles-nix#${nodename}"'';
                nrf = ''nix flake update --flake "path:/home/vir/git-repos/dotfiles-nix" && sudo nixos-rebuild switch --flake "path:/home/vir/git-repos/dotfiles-nix#${nodename}" --refresh'';
              };
              initContent = ''
                # Enable Powerlevel10k instant prompt
                if [[ -r "''${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-''${(%):-%n}.zsh" ]]; then
                  source "''${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-''${(%):-%n}.zsh"
                fi

                # To customize prompt, run `p10k configure` or edit ~/.p10k.zsh
                [[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
              '';
            };
          };
        };
    };
}
