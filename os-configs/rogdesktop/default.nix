{
  home-manager,
  pkgs,
  lib,
  ...
}:
{
  home-manager.users.vir =
    { pkgs, lib, ... }:
    {

      xsession.initExtra = ''
          xset -dpms
          xset s off
          xset s noblank
        '';

    };
}
