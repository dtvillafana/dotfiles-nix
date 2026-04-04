{ ... }:
{
  flake.homeModules.zathura =
    { ... }:
    {
      programs.zathura = {
        enable = true;
        options = {
          selection-clipboard = "clipboard";
        };
      };
    };
}
