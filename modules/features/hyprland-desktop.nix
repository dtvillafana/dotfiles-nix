{ ... }:
{
  flake.nixosModules.hyprlandDesktop =
    { pkgs, ... }:
    {
      programs.hyprland = {
        enable = true;
        withUWSM = true;
        xwayland.enable = true;
      };
      programs.hyprlock.enable = true;
      security.pam.services.quickshell-lock = { };
      programs.ydotool.enable = true;
      xdg.portal = {
        extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
        config.hyprland = {
          default = [
            "hyprland"
            "gtk"
          ];
          "org.freedesktop.impl.portal.FileChooser" = [ "gtk" ];
        };
      };
      # These options also generate the console keymap; they do not enable Xorg.
      services.xserver.xkb = {
        layout = "us";
        options = "ctrl:swapcaps";
      };
      console.useXkbConfig = true;
    };
}
