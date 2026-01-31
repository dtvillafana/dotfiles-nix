{ ... }:
{

  services.xserver.displayManager.sessionCommands = ''
    xset dpms 0 0 0
    xset s 2700 5
    xset s blank
  '';

}
