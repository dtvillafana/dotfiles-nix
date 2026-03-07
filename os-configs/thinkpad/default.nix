{ pkgs, ... }:
{
  programs.adb.enable = true;
  users.users.vir.extraGroups = [
    "adbusers"
  ];
  users.groups.adbusers = { };
}
