{ ... }:
{
  flake.nixosModules.capcuDellBootstrapConfig =
    { pkgs, ... }:
    {
      users.users.bootstrap = {
        initialHashedPassword = "$y$j9T$qTtCIlz3KyW/1WKELiesF0$7nCjPFCkT8Ww04ieHzXVW8sJ2LZhL04fnENrTiP6s.C";
        isNormalUser = true;
        description = "bootstrap";
        extraGroups = [
          "networkmanager"
          "wheel"
          "dialout"
          "tty"
        ];
        packages = with pkgs; [
          curl
          git
          neovim
        ];
        shell = pkgs.zsh;
      };
      users.groups.bootstrap = { };
    };
}
