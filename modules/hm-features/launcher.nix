{ ... }:
{
  flake.homeModules.launcher =
    { pkgs, ... }:
    {
      gtk = {
        enable = true;
        iconTheme = {
          name = "Papirus-Dark";
          package = pkgs.papirus-icon-theme;
        };
      };

      programs.fuzzel = {
        enable = true;
        settings = {
          main = {
            font = "DejaVu Sans:size=12";
            prompt = "Search apps… ";
            terminal = "ghostty -e";
            launch-prefix = "uwsm app --";
            anchor = "center";
            width = 55;
            lines = 10;
            match-mode = "fzf";
            list-executables-in-path = true;
            sort-result = true;
            icon-theme = "Papirus-Dark";
            horizontal-pad = 16;
            vertical-pad = 12;
            inner-pad = 8;
          };
          colors = {
            background = "1e1e2eff";
            text = "cdd6f4ff";
            prompt = "cdd6f4ff";
            input = "cdd6f4ff";
            match = "89b4faff";
            selection = "89b4faff";
            selection-text = "1e1e2eff";
            selection-match = "313244ff";
            border = "585b70ff";
          };
          border = {
            width = 1;
            radius = 12;
          };
        };
      };
    };
}
