{
  ...
}:
{
  flake.nixosModules.git-repos =
    {
      config,
      home-manager,
      pkgs,
      ...
    }:
    let
      external_git_repos = [
        {
          name = "nixvim";
          url = "https://dtvillafana:$(cat ${config.sops.secrets.git_github.path})@github.com/dtvillafana/nixvim";
          path = "$HOME/git-repos/nixvim";
        }
        {
          name = "nixvim-for-pr";
          url = "https://dtvillafana:$(cat ${config.sops.secrets.git_github.path})@github.com/dtvillafana/nixvim-for-pr";
          path = "$HOME/git-repos/nixvim-for-pr";
        }
        {
          name = "orgmode";
          url = "https://dtvillafana:$(cat ${config.sops.secrets.git_github.path})@github.com/dtvillafana/orgmode";
          path = "$HOME/git-repos/orgmode";
        }
        {
          name = "orgfiles";
          url = "https://dvillafanaiv:$(cat ${config.sops.secrets.git_gitlab.path})@gitlab.com/personal2673713/org.git";
          path = "$HOME/git-repos/orgfiles";
        }
        {
          name = "spectrum-orgfiles";
          url = "https://dvillafanaiv:$(cat ${config.sops.secrets.git_gitlab.path})@gitlab.com/spectrum-it-solutions/orgfiles.git";
          path = "$HOME/git-repos/spectrum-orgfiles";
        }
        {
          name = "homelab-nixos-generators";
          url = "https://dvillafanaiv:$(cat ${config.sops.secrets.git_gitlab.path})@gitlab.com/spectrum-it-solutions/nixos-generators.git";
          path = "$HOME/git-repos/homelab-nixos-generators";
        }
        {
          name = "i-got-a-buddy-web";
          url = "https://dtvillafana:$(cat ${config.sops.secrets.git_github.path})@github.com/dtvillafana/i-got-a-buddy-web";
          path = "$HOME/git-repos/i-got-a-buddy-web";
        }
        {
          name = "org-notifier";
          url = "https://dtvillafana:$(cat ${config.sops.secrets.git_github.path})@github.com/dtvillafana/org-notifier";
          path = "$HOME/git-repos/org-notifier";
        }
        {
          name = "liber-usualis";
          url = "https://dtvillafana:$(cat ${config.sops.secrets.git_github.path})@github.com/mkbertrand/liber-usualis";
          path = "$HOME/git-repos/liber-usualis";
        }
        {
          name = "finances";
          url = "vps:~/git-repos/finances";
          path = "$HOME/git-repos/finances";
        }
        {
          name = "dotfiles-nix";
          url = "https://dtvillafana:$(cat ${config.sops.secrets.git_github.path})@github.com/dtvillafana/dotfiles-nix";
          path = "$HOME/git-repos/dotfiles-nix";
        }
        {
          name = "cand-data-interface-api-service";
          url = "https://dtvillafana:$(cat ${config.sops.secrets.git_github.path})@github.com/spectrum-it-solutions/cand-data-interface-api-service";
          path = "$HOME/git-repos/cand-data-interface-api-service";
        }
        {
          name = "cand-data-interface-sql";
          url = "https://dtvillafana:$(cat ${config.sops.secrets.git_github.path})@github.com/spectrum-it-solutions/cand-data-interface-sql";
          path = "$HOME/git-repos/cand-data-interface-sql";
        }
        {
          name = "csc-106";
          url = "https://dtvillafana:$(cat ${config.sops.secrets.git_github.path})@github.com/dtvillafana/csc-106";
          path = "$HOME/git-repos/csc-106";
        }
        {
          name = "charachorder-config";
          url = "https://dtvillafana:$(cat ${config.sops.secrets.git_github.path})@github.com/dtvillafana/charachorder-config";
          path = "$HOME/git-repos/charachorder-config";
        }
        {
          name = "CSC-106-practice";
          url = "https://github.com/dtvillafana/CSC-106-practice";
          path = "$HOME/git-repos/CSC-106-practice";
        }
      ];

      make_git_forge_repo_action = repo: {
        name = "clone_${builtins.replaceStrings [ "-" ] [ "_" ] repo.name}";
        value = home-manager.lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          if [ ! -d "${repo.path}" ]; then
              export GIT_SSH="${pkgs.openssh}/bin/ssh"
              if ${pkgs.iputils}/bin/ping -c 1 github.com &> /dev/null; then
                  ${pkgs.git}/bin/git clone "${repo.url}" "${repo.path}"
              else
                  echo "Network unreachable. Skipping clone."
              fi
          else
              cd "${repo.path}" && ${pkgs.git}/bin/git pull || true
          fi
        '';
      };

      external_git_actions = builtins.listToAttrs (map make_git_forge_repo_action external_git_repos);

    in
    {
      home-manager.users.vir =
        {
          self,
          ...
        }:
        {
          home.activation = external_git_actions;
        };
    };
}
