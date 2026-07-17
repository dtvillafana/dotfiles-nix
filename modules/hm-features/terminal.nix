{ ... }:
{
  flake.homeModules.terminal =
    { ... }:
    {
      programs = {
        ghostty = {
          enable = true;
          settings = {
            app-notifications = [ "no-clipboard-copy" ];
            window-decoration = "none";
            window-show-tab-bar = "auto";
            gtk-titlebar = false;
            clipboard-read = "allow";
            clipboard-write = "allow";
            keybind = [
              "ctrl+enter=unbind"
            ];
          };
        };
      };
    };
}
