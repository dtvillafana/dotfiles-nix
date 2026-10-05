{ self, ... }:
{
  flake.homeModules.git-repos-all =
    {
      config,
      osConfig,
      ...
    }:
    let
      githubSecret = osConfig.sops.secrets."git_github_${config.home.username}".path;
      gitlabSecret = osConfig.sops.secrets."git_gitlab_pat_${config.home.username}".path;
    in
    {
      imports = [ self.homeModules.git-repos ];

      gitRepos.repositories = [
        {
          name = "opencode-nvim";
          url = "https://dtvillafana:$(cat ${githubSecret})@github.com/dtvillafana/opencode.nvim";
          path = "$HOME/git-repos/opencode-nvim";
          secret = githubSecret;
        }
        {
          name = "CIS-300-UMary";
          url = "https://dtvillafana:$(cat ${githubSecret})@github.com/dtvillafana/CIS-300-UMary";
          path = "$HOME/git-repos/CIS-300-UMary";
          secret = githubSecret;
        }
        {
          name = "n8n";
          url = "https://dtvillafana:$(cat ${githubSecret})@github.com/dtvillafana/n8n";
          path = "$HOME/git-repos/n8n";
          secret = githubSecret;
        }
        {
          name = "nixvim";
          url = "https://dtvillafana:$(cat ${githubSecret})@github.com/dtvillafana/nixvim";
          path = "$HOME/git-repos/nixvim";
          secret = githubSecret;
        }
        {
          name = "nixvim-for-pr";
          url = "https://dtvillafana:$(cat ${githubSecret})@github.com/dtvillafana/nixvim-for-pr";
          path = "$HOME/git-repos/nixvim-for-pr";
          secret = githubSecret;
        }
        {
          name = "orgmode";
          url = "https://dtvillafana:$(cat ${githubSecret})@github.com/dtvillafana/orgmode";
          path = "$HOME/git-repos/orgmode";
          secret = githubSecret;
        }
        {
          name = "orgfiles";
          url = "https://dvillafanaiv:$(cat ${gitlabSecret})@gitlab.com/personal2673713/org.git";
          path = "$HOME/git-repos/orgfiles";
          secret = gitlabSecret;
        }
        {
          name = "spectrum-orgfiles";
          url = "https://dvillafanaiv:$(cat ${gitlabSecret})@gitlab.com/spectrum-it-solutions/orgfiles.git";
          path = "$HOME/git-repos/spectrum-orgfiles";
          secret = gitlabSecret;
        }
        {
          name = "homelab-nixos-generators";
          url = "https://dvillafanaiv:$(cat ${gitlabSecret})@gitlab.com/spectrum-it-solutions/nixos-generators.git";
          path = "$HOME/git-repos/homelab-nixos-generators";
          secret = gitlabSecret;
        }
        {
          name = "org-notifier";
          url = "https://dtvillafana:$(cat ${githubSecret})@github.com/dtvillafana/org-notifier";
          path = "$HOME/git-repos/org-notifier";
          secret = githubSecret;
        }
        {
          name = "dotfiles-nix";
          url = "https://dtvillafana:$(cat ${githubSecret})@github.com/dtvillafana/dotfiles-nix";
          path = "$HOME/git-repos/dotfiles-nix";
          secret = githubSecret;
        }
        {
          name = "charachorder-config";
          url = "https://dtvillafana:$(cat ${githubSecret})@github.com/dtvillafana/charachorder-config";
          path = "$HOME/git-repos/charachorder-config";
          secret = githubSecret;
        }
      ];
    };
}
