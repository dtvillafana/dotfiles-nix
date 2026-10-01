{
  lib,
  ags,
  astal,
  hyprwhichkey-src,
}:

ags.bundle {
  pname = "hyprwhichkey";
  version = "0-unstable-2025-05-05";
  src = hyprwhichkey-src;
  patches = [ ./hyprwhichkey-held.patch ];
  entry = "src/app.ts";
  dependencies = [ astal.hyprland ];

  meta = {
    description = "Which-key binding overlay for Hyprland";
    homepage = "https://github.com/Juhan280/hyprwhichkey";
    license = lib.licenses.mit;
    mainProgram = "hyprwhichkey";
    platforms = lib.platforms.linux;
  };
}
