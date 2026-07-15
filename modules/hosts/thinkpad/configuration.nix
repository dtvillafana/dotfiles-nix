{ ... }:
{
  flake.nixosModules.thinkpadConfig =
    { ... }:
    {
      home-manager.users = builtins.listToAttrs (
        map
          (username: {
            name = username;
            value =
              { pkgs, ... }:
              {
                home.packages = with pkgs; [
                  android-tools
                ];
              };
          })
          [
            "vir"
            "capcu"
          ]
      );
      users.users.vir.extraGroups = [ "adbusers" ];
      users.users.capcu.extraGroups = [ "adbusers" ];
      users.groups.adbusers = { };
    };
}
