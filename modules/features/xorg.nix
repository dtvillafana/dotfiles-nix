{ ... }:
{
  flake.nixosModules.xorg =
    { ... }:
    {
      programs.i3lock.enable = true;
      services.xserver = {
        enable = true;

        displayManager.startx.enable = true;

        desktopManager.xterm.enable = false;

        xkb = {
          layout = "us";
          options = "ctrl:swapcaps";
        };
      };

      console.useXkbConfig = true;
    };
}
