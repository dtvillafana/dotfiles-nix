{ self, inputs, ... }:
{
  flake.nixosModules.zathura =
    { ... }:
    {
      home-manager.users.vir =
        { pkgs, ... }:
        {
          programs.zathura = {
            enable = true;
            options = {
              selection-clipboard = "clipboard";
            };
          };
        };
    };
}
