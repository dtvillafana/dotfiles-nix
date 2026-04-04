{ ... }:
{
  flake.homeModules.git =
    { osConfig, pkgs, ... }:
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
            "store --file=${osConfig.users.users.vir.home}/.git-credentials-github";
          credential."https://gitlab.com".helper =
            "store --file=${osConfig.users.users.vir.home}/.git-credentials-gitlab";
          credential."https://bitbucket.org".helper =
            "store --file=${osConfig.users.users.vir.home}/.git-credentials-bitbucket";
        };
        lfs.enable = true;
      };
    };
}
