{ ... }:
{
  flake.homeModules.git-repos =
    {
      osConfig,
      lib,
      pkgs,
      ...
    }:
    let
      external_git_repos = [
        {
          name = "resumes";
          url = "https://dtvillafana:$(cat ${osConfig.sops.secrets.git_github.path})@github.com/dtvillafana/resumes";
          path = "$HOME/git-repos/resumes";
          secret = osConfig.sops.secrets.git_github.path;
        }
        {
          name = "nixvim";
          url = "https://dtvillafana:$(cat ${osConfig.sops.secrets.git_github.path})@github.com/dtvillafana/nixvim";
          path = "$HOME/git-repos/nixvim";
          secret = osConfig.sops.secrets.git_github.path;
        }
        {
          name = "nixvim-for-pr";
          url = "https://dtvillafana:$(cat ${osConfig.sops.secrets.git_github.path})@github.com/dtvillafana/nixvim-for-pr";
          path = "$HOME/git-repos/nixvim-for-pr";
          secret = osConfig.sops.secrets.git_github.path;
        }
        {
          name = "orgmode";
          url = "https://dtvillafana:$(cat ${osConfig.sops.secrets.git_github.path})@github.com/dtvillafana/orgmode";
          path = "$HOME/git-repos/orgmode";
          secret = osConfig.sops.secrets.git_github.path;
        }
        {
          name = "orgfiles";
          url = "https://dvillafanaiv:$(cat ${osConfig.sops.secrets.git_gitlab_pat.path})@gitlab.com/personal2673713/org.git";
          path = "$HOME/git-repos/orgfiles";
          secret = osConfig.sops.secrets.git_gitlab_pat.path;
        }
        {
          name = "spectrum-orgfiles";
          url = "https://dvillafanaiv:$(cat ${osConfig.sops.secrets.git_gitlab_pat.path})@gitlab.com/spectrum-it-solutions/orgfiles.git";
          path = "$HOME/git-repos/spectrum-orgfiles";
          secret = osConfig.sops.secrets.git_gitlab_pat.path;
        }
        {
          name = "homelab-nixos-generators";
          url = "https://dvillafanaiv:$(cat ${osConfig.sops.secrets.git_gitlab_pat.path})@gitlab.com/spectrum-it-solutions/nixos-generators.git";
          path = "$HOME/git-repos/homelab-nixos-generators";
          secret = osConfig.sops.secrets.git_gitlab_pat.path;
        }
        {
          name = "chaseballots";
          url = "https://dvillafanaiv:$(cat ${osConfig.sops.secrets.git_gitlab_pat.path})@gitlab.com/spectrum-it-solutions/chaseballots.git";
          path = "$HOME/git-repos/chaseballots";
          secret = osConfig.sops.secrets.git_gitlab_pat.path;
        }
        {
          name = "ca-gotv";
          url = "https://dvillafanaiv:$(cat ${osConfig.sops.secrets.git_gitlab_pat.path})@gitlab.com/spectrum-it-solutions/ca-gotv.git";
          path = "$HOME/git-repos/ca-gotv";
          secret = osConfig.sops.secrets.git_gitlab_pat.path;
        }
        {
          name = "i-got-a-buddy-web";
          url = "https://dtvillafana:$(cat ${osConfig.sops.secrets.git_github.path})@github.com/dtvillafana/i-got-a-buddy-web";
          path = "$HOME/git-repos/i-got-a-buddy-web";
          secret = osConfig.sops.secrets.git_github.path;
        }
        {
          name = "org-notifier";
          url = "https://dtvillafana:$(cat ${osConfig.sops.secrets.git_github.path})@github.com/dtvillafana/org-notifier";
          path = "$HOME/git-repos/org-notifier";
          secret = osConfig.sops.secrets.git_github.path;
        }
        {
          name = "liber-usualis";
          url = "https://dtvillafana:$(cat ${osConfig.sops.secrets.git_github.path})@github.com/mkbertrand/liber-usualis";
          path = "$HOME/git-repos/liber-usualis";
          secret = osConfig.sops.secrets.git_github.path;
        }
        {
          name = "finances";
          url = "vps:~/git-repos/finances";
          path = "$HOME/git-repos/finances";
        }
        {
          name = "dotfiles-nix";
          url = "https://dtvillafana:$(cat ${osConfig.sops.secrets.git_github.path})@github.com/dtvillafana/dotfiles-nix";
          path = "$HOME/git-repos/dotfiles-nix";
          secret = osConfig.sops.secrets.git_github.path;
        }
        {
          name = "cand-data-interface-api-service";
          url = "https://dtvillafana:$(cat ${osConfig.sops.secrets.git_github.path})@github.com/spectrum-it-solutions/cand-data-interface-api-service";
          path = "$HOME/git-repos/cand-data-interface-api-service";
          secret = osConfig.sops.secrets.git_github.path;
        }
        {
          name = "cand-data-interface-sql";
          url = "https://dtvillafana:$(cat ${osConfig.sops.secrets.git_github.path})@github.com/spectrum-it-solutions/cand-data-interface-sql";
          path = "$HOME/git-repos/cand-data-interface-sql";
          secret = osConfig.sops.secrets.git_github.path;
        }
        {
          name = "csc-106";
          url = "https://dtvillafana:$(cat ${osConfig.sops.secrets.git_github.path})@github.com/dtvillafana/csc-106";
          path = "$HOME/git-repos/csc-106";
          secret = osConfig.sops.secrets.git_github.path;
        }
        {
          name = "charachorder-config";
          url = "https://dtvillafana:$(cat ${osConfig.sops.secrets.git_github.path})@github.com/dtvillafana/charachorder-config";
          path = "$HOME/git-repos/charachorder-config";
          secret = osConfig.sops.secrets.git_github.path;
        }
        {
          name = "CSC-106-practice";
          url = "https://github.com/dtvillafana/CSC-106-practice";
          path = "$HOME/git-repos/CSC-106-practice";
        }
        {
          name = "django-supabase-storage";
          url = "https://dtvillafana:$(cat ${osConfig.sops.secrets.git_github.path})@github.com/dtvillafana/django-supabase-storage";
          path = "$HOME/git-repos/django-supabase-storage";
          secret = osConfig.sops.secrets.git_github.path;
        }
      ];

      syncRepo = repo: ''
        echo "Syncing ${repo.name}..."
        if [ ! -d "${repo.path}" ]; then
            if ${if repo ? secret then ''[ -r "${repo.secret}" ]'' else "true"}; then
                mkdir -p "$(${pkgs.coreutils}/bin/dirname "${repo.path}")"
                export GIT_SSH="${pkgs.openssh}/bin/ssh"
                ${pkgs.git}/bin/git clone "${repo.url}" "${repo.path}" || true
            else
                echo "Skipping ${repo.name}: cannot read ${
                  if repo ? secret then repo.secret else "required secret"
                }."
            fi
        else
            (cd "${repo.path}" && ${pkgs.git}/bin/git pull) || true
        fi
      '';

    in
    {
      home.packages = [
        (pkgs.writeShellScriptBin "sync-repos" ''
          set -u

          ${lib.concatMapStringsSep "\n" syncRepo external_git_repos}
        '')
      ];
    };
}
