{ ... }:
{
  # Shared options and commands; repository modules contribute to the same list.
  flake.homeModules.git-repos =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      syncRepo =
        repo:
        if repo.discovery == "gitea" then
          ''
            if [ -r "${repo.secret}" ]; then
              GITEA_TOKEN=$(cat "${repo.secret}")
              GITEA_URL="${repo.url}"
              REPOS_DIR="${repo.path}"
              mkdir -p "$REPOS_DIR"

              page=1
              while true; do
                repos=$(${pkgs.curl}/bin/curl -fsS -H "Authorization: token $GITEA_TOKEN" \
                  "$GITEA_URL/api/v1/user/repos?page=$page&limit=50" | ${pkgs.jq}/bin/jq -r '.[] | select(.mirror != true) | .full_name')

                if [ -z "$repos" ]; then
                  break
                fi

                for repo in $repos; do
                  repo_path="$REPOS_DIR/$repo"
                  echo "Syncing $repo..."
                  if [ ! -d "$repo_path" ]; then
                    mkdir -p "$(${pkgs.coreutils}/bin/dirname "$repo_path")"
                    ${pkgs.git}/bin/git clone "$GITEA_URL/$repo" "$repo_path" || true
                  else
                    (cd "$repo_path" && ${pkgs.git}/bin/git pull) || true
                  fi
                done

                page=$((page + 1))
              done
            else
              echo "Skipping ${repo.name}: cannot read ${repo.secret}."
            fi
          ''
        else
          ''
            echo "Syncing ${repo.name}..."
            if [ ! -d "${repo.path}" ]; then
              if ${if repo.secret != null then ''[ -r "${repo.secret}" ]'' else "true"}; then
                mkdir -p "$(${pkgs.coreutils}/bin/dirname "${repo.path}")"
                ${pkgs.git}/bin/git clone "${repo.url}" "${repo.path}" || true
              else
                echo "Skipping ${repo.name}: cannot read ${
                  if repo.secret != null then repo.secret else "required secret"
                }."
              fi
            else
              (cd "${repo.path}" && ${pkgs.git}/bin/git pull) || true
            fi
          '';

      syncScript =
        name: repos:
        pkgs.writeShellScriptBin name ''
          set -u
          export GIT_SSH="${pkgs.openssh}/bin/ssh"

          ${lib.concatMapStringsSep "\n" syncRepo repos}
        '';
    in
    {
      key = "dotfiles-nix-git-repos";

      options.gitRepos.repositories = lib.mkOption {
        description = "Merged repository list used by sync-repos and sync-work-repos.";
        default = [ ];
        type = lib.types.listOf (
          lib.types.submodule {
            options = {
              name = lib.mkOption { type = lib.types.str; };
              url = lib.mkOption { type = lib.types.str; };
              path = lib.mkOption { type = lib.types.str; };
              secret = lib.mkOption {
                type = lib.types.nullOr lib.types.str;
                default = null;
              };
              work = lib.mkOption {
                type = lib.types.bool;
                default = false;
              };
              discovery = lib.mkOption {
                type = lib.types.enum [
                  "none"
                  "gitea"
                ];
                default = "none";
                description = "Clone one repository, or discover non-mirror repositories from Gitea.";
              };
            };
          }
        );
      };

      config._module.args.gitReposSyncScript = syncScript;

      config.home.packages = [
        (syncScript "sync-repos" config.gitRepos.repositories)
      ];
    };
}
