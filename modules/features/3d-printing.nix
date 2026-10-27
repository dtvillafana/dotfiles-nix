{ inputs, ... }:
{
  flake.nixosModules.printing3d =
    { pkgs, ... }:
    {
      services.octoprint = {
        enable = true;
        host = "127.0.0.1";
        package = pkgs.callPackage ../../packages/octoprint.nix {
          inherit (inputs) octoprint-src octoprint-filecheck-src octoprint-firmwarecheck-src;
        };
        plugins = ps: [
          (ps.callPackage ../../packages/octoprint-malyan-connection-fix.nix {
            inherit (inputs) octoprint-malyan-connection-fix-src;
          })
        ];
        extraConfig.serial = {
          port = "/dev/serial/by-id/usb-Malyan_System_Malyan_3D_Printer_206F35724252-if00";
          baudrate = 115200;
          # Connecting must remain an explicit action while troubleshooting motion.
          autoconnect = false;
        };
      };
    };
}
