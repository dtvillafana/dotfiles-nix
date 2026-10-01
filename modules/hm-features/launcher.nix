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

      programs.wofi = {
        enable = true;
        settings = {
          show = "drun,run";
          prompt = "Search apps and commands…";
          term = "ghostty";
          location = "center";
          width = 640;
          lines = 8;
          dynamic_lines = true;
          matching = "fuzzy";
          insensitive = true;
          allow_images = true;
          allow_markup = false;
          image_size = 24;
          hide_scroll = true;
          gtk_dark = true;
          "drun-display_generic" = true;
          "run-always_parse_args" = true;
          "run-show_all" = false;
        };
        style = ''
          * {
            font-family: "DejaVu Sans", sans-serif;
            font-size: 15px;
          }

          #window {
            background-color: rgba(30, 30, 46, 0.97);
            color: #cdd6f4;
            border: 1px solid #585b70;
            border-radius: 18px;
          }

          #outer-box { padding: 16px; }

          #input {
            padding: 12px 16px;
            margin-bottom: 12px;
            background-color: #313244;
            color: #cdd6f4;
            border: 1px solid #45475a;
            border-radius: 12px;
            box-shadow: none;
          }

          #input:focus { border-color: #89b4fa; }
          #scroll { background-color: transparent; }
          #entry { padding: 10px 12px; border-radius: 10px; }
          #entry:selected { background-color: #89b4fa; }
          #text { margin: 0 8px; color: #cdd6f4; }
          #text:selected { color: #1e1e2e; }
          #img { margin-right: 8px; }
        '';
      };
    };
}
