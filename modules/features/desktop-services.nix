{ ... }:
{
  flake.nixosModules.desktopServices =
    { pkgs, ... }:
    {
      fonts.packages = with pkgs.nerd-fonts; [
        jetbrains-mono
        symbols-only
      ];
      networking.networkmanager.enable = true;
      services.printing.enable = true;
      hardware.bluetooth.enable = true;
      services.pulseaudio.enable = false;
      security.rtkit.enable = true;
      services.pipewire = {
        enable = true;
        alsa.enable = true;
        alsa.support32Bit = true;
        pulse.enable = true;
      };
      environment.systemPackages = [ pkgs.pavucontrol ];
    };
}
