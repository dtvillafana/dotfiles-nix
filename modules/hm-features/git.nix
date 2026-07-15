{ ... }:
{
  flake.homeModules.git =
    { config, pkgs, ... }:
    {
      programs.git = {
        enable = true;
        settings = {
          user = {
            name = "dtvillafana";
            email = "82293276+dtvillafana@users.noreply.github.com";
          };
          core.sshCommand = "${pkgs.openssh}/bin/ssh";
          credential."https://github.com".helper =
            "store --file=${config.home.homeDirectory}/.git-credentials-github";
          credential."https://gitlab.com".helper =
            "store --file=${config.home.homeDirectory}/.git-credentials-gitlab";
          credential."https://codeberg.org".helper =
            "store --file=${config.home.homeDirectory}/.git-credentials-codeberg";
        };
        lfs.enable = true;
      };
    };
}
