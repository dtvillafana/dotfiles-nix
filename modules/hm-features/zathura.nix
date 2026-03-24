{ ... }:
{
  flake.nixosModules.zathura =
    { ... }:
    {
      home-manager.users.vir =
        { ... }:
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
