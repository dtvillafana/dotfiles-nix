{
  home-manager,
  pkgs,
  lib,
  ...
}:
{
  services.xserver.videoDrivers = [ "nvidia" ];

  programs.adb.enable = true;
  users.users.vir.extraGroups = [
    "adbusers"
  ];
  users.groups.adbusers = {};

  hardware.nvidia = {
    modesetting.enable = true;
    open = false;
  };

  hardware.graphics.enable = true;

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
