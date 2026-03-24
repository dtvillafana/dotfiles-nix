{ ... }:
{
  flake.nixosModules.thinkpadConfig =
    { ... }:
    {
      home-manager.users.vir =
        { pkgs, ... }:
        {
          home.packages = with pkgs; [
            android-tools
          ];
        };
      users.users.vir.extraGroups = [
        "adbusers"
      ];
      users.groups.adbusers = { };
    };
}
