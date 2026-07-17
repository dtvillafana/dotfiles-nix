{ ... }:
{
  flake.homeModules.zsh =
    {
      config,
      lib,
      nixvim,
      system,
      osConfig,
      pkgs,
      ...
    }:
    let
      dotfiles = "path:/home/${config.home.username}/git-repos/dotfiles-nix";
      sopsSshKey = "${config.home.homeDirectory}/.ssh/id_ed25519";
    in
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
            SOPS_AGE_SSH_PRIVATE_KEY_FILE = sopsSshKey;
            SOPS_AGE_KEY_CMD = "${lib.getExe pkgs.ssh-to-age} -private-key -i ${sopsSshKey}";
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
            nr = ''nix flake update --flake "${dotfiles}" nixvim && sudo nixos-rebuild switch --flake "${dotfiles}#${osConfig.networking.hostName}"'';
            nrf = ''nix flake update --flake "${dotfiles}" && sudo nixos-rebuild switch --flake "${dotfiles}#${osConfig.networking.hostName}" --refresh'';
            nrc = ''nix flake update --flake "${dotfiles}" nixvim nix-index-database && sudo nixos-rebuild switch --flake "${dotfiles}#${osConfig.networking.hostName}" --refresh && nix-collect-garbage -d && nix store optimise'';
            nrfc = ''nix flake update --flake "${dotfiles}" && sudo nixos-rebuild switch --flake "${dotfiles}#${osConfig.networking.hostName}" --refresh && nix-collect-garbage -d && nix store optimise'';
            sync-repos = "sync-repos";
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
}
