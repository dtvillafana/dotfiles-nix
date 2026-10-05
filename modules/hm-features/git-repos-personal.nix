{ self, ... }:
{
  flake.homeModules.git-repos-personal =
    {
      osConfig,
      config,
      ...
    }:
    let
      githubSecret = osConfig.sops.secrets."git_github_${config.home.username}".path;
      gitlabSecret = osConfig.sops.secrets."git_gitlab_pat_${config.home.username}".path;
      codebergSecret = osConfig.sops.secrets."git_codeberg_${config.home.username}".path;
      dvillaSecret = osConfig.sops.secrets."git_dvilla_${config.home.username}".path;
    in
    {
      imports = [ self.homeModules.git-repos ];

      gitRepos.repositories = [
        {
          name = "NDRL-notes";
          url = "https://david:$(cat ${dvillaSecret})@git.dvilla.me/david/NDRL-notes";
          path = "$HOME/git-repos/NDRL-notes";
          secret = dvillaSecret;
        }
        {
          name = "resumes";
          url = "https://dtvillafana:$(cat ${githubSecret})@github.com/dtvillafana/resumes";
          path = "$HOME/git-repos/resumes";
          secret = githubSecret;
        }
        {
          name = "chaseballots";
          url = "https://dvillafanaiv:$(cat ${gitlabSecret})@gitlab.com/spectrum-it-solutions/chaseballots.git";
          path = "$HOME/git-repos/chaseballots";
          secret = gitlabSecret;
        }
        {
          name = "ca-gotv";
          url = "https://dvillafanaiv:$(cat ${gitlabSecret})@gitlab.com/spectrum-it-solutions/ca-gotv.git";
          path = "$HOME/git-repos/ca-gotv";
          secret = gitlabSecret;
        }
        {
          name = "i-got-a-buddy-web";
          url = "https://dtvillafana:$(cat ${githubSecret})@github.com/dtvillafana/i-got-a-buddy-web";
          path = "$HOME/git-repos/i-got-a-buddy-web";
          secret = githubSecret;
        }
        {
          name = "liber-usualis";
          url = "https://dtvillafana:$(cat ${githubSecret})@github.com/mkbertrand/liber-usualis";
          path = "$HOME/git-repos/liber-usualis";
          secret = githubSecret;
        }
        {
          name = "finances";
          url = "https://david:$(cat ${dvillaSecret})@git.dvilla.me/david/finances";
          path = "$HOME/git-repos/finances";
          secret = dvillaSecret;
        }
        {
          name = "cand-data-interface-api-service";
          url = "https://dtvillafana:$(cat ${githubSecret})@github.com/spectrum-it-solutions/cand-data-interface-api-service";
          path = "$HOME/git-repos/cand-data-interface-api-service";
          secret = githubSecret;
        }
        {
          name = "cand-data-interface-sql";
          url = "https://dtvillafana:$(cat ${githubSecret})@github.com/spectrum-it-solutions/cand-data-interface-sql";
          path = "$HOME/git-repos/cand-data-interface-sql";
          secret = githubSecret;
        }
        {
          name = "call-transcriber";
          url = "https://dvillafanaiv:$(cat ${codebergSecret})@codeberg.org/dvillafanaiv/call-transcriber";
          path = "$HOME/git-repos/call-transcriber";
          secret = codebergSecret;
        }
        {
          name = "django-supabase-storage";
          url = "https://dtvillafana:$(cat ${githubSecret})@github.com/dtvillafana/django-supabase-storage";
          path = "$HOME/git-repos/django-supabase-storage";
          secret = githubSecret;
        }
      ];
    };
}
