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
          credential."https://git.dvilla.me".helper =
            "store --file=${config.home.homeDirectory}/.git-credentials-dvilla";
        };
        lfs.enable = true;
      };
    };

  flake.homeModules.lazygit =
    { lib, pkgs, ... }:
    {
      home.packages = [
        (pkgs.writeShellScriptBin "lazygit" ''
          # OpenCode's embedded terminal can turn Shift+P into p:
          # https://github.com/anomalyco/opencode/issues/65345
          export TCELL_KEYBOARD_PROTOCOL="''${TCELL_KEYBOARD_PROTOCOL:-legacy}"
          exec ${lib.getExe pkgs.lazygit} "$@"
        '')
      ];
    };
}
