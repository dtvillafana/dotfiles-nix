{ ... }:
{
  flake.homeModules.launcher =
    { ... }:
    {
      programs.rofi = {
        enable = true;
        terminal = "ghostty";
        theme = "Arc-Dark";
        font = "DejaVu Sans Mono 11";
        extraConfig = {
          modi = "run,drun";
          icon-theme = "Papirus";
          show-icons = true;
          drun-display-format = "{name} [<span weight='light' size='small'><i>({generic})</i></span>]";
          disable-history = false;
          hide-scrollbar = true;
        };
      };
    };
}
