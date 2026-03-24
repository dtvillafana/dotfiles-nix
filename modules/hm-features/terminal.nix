{ self, inputs, ... }:
{
  flake.nixosModules.terminal =
    { ... }:
    {
      home-manager.users.vir =
        { pkgs, ... }:
        {
          programs = {
            ghostty = {
              enable = true;
              settings = {
                window-decoration = "none";
                gtk-titlebar = false;
                keybind = [
                  "ctrl+enter=unbind"
                ];
              };
            };
          };
        };
    };
}
