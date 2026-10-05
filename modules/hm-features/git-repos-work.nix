{ self, ... }:
{
  flake.homeModules.git-repos-work =
    {
      osConfig,
      config,
      lib,
      gitReposSyncScript,
      ...
    }:
    let
      githubSecret = osConfig.sops.secrets."git_github_${config.home.username}".path;
    in
    {
      imports = [ self.homeModules.git-repos ];

      gitRepos.repositories = [
        {
          name = "m365-tui";
          url = "https://dtvillafana:$(cat ${githubSecret})@github.com/dtvillafana/m365-tui";
          path = "$HOME/git-repos/m365-tui";
          secret = githubSecret;
          work = true;
        }
        {
          name = "capcu";
          url = "https://ccugitea.capcu.org";
          path = "$HOME/capcu-git-repos";
          secret = osConfig.sops.secrets.gitea_token.path;
          work = true;
          discovery = "gitea";
        }
      ];

      home.packages = [
        (gitReposSyncScript "sync-work-repos" (lib.filter (repo: repo.work) config.gitRepos.repositories))
      ];
    };
}
