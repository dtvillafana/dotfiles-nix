{ ... }:
{

  services.xserver.displayManager.sessionCommands = ''
    xset -dpms
    xset s off
    xset s noblank
  '';

}
