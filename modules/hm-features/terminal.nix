{ ... }:
{
  flake.nixosModules.terminal =
    { ... }:
    {
      home-manager.users.vir =
        { ... }:
        {
          programs = {
            ghostty = {
              enable = true;
              settings = {
                app-notifications = [ "no-clipboard-copy" ];
                window-decoration = "none";
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
    };
}
