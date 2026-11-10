{ ... }:
{
  flake.homeModules.remmina =
    { pkgs, ... }:
    {
      home.packages = [ pkgs.remmina ];
    };
}
