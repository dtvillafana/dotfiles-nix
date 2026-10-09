{ ... }:
{
  flake.nixosModules.office =
    { pkgs, ... }:
    let
      libreofficeDraw = pkgs.symlinkJoin {
        name = "libreoffice-draw";
        paths = [
          (pkgs.writeShellApplication {
            name = "libreoffice-draw";
            runtimeInputs = [ pkgs.libreoffice ];
            text = ''
              exec libreoffice --draw "$@"
            '';
          })
          (pkgs.makeDesktopItem {
            name = "libreoffice-draw";
            desktopName = "LibreOffice Draw";
            exec = "libreoffice-draw %U";
            categories = [
              "Graphics"
              "VectorGraphics"
            ];
            type = "Application";
          })
        ];
      };
    in
    {
      environment.systemPackages = [
        libreofficeDraw
        pkgs.onlyoffice-desktopeditors
      ];
    };
}
