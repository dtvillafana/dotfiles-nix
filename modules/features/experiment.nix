{ ... }:
{
  flake.nixosModules.experiment =
    { pkgs, ... }:
    {
      services.docuseal = {
        enable = false;
        # secretKeyBaseFile = pkgs.writeText "secret-key-base" "9d34f2092903e4891d7cc28a7534ee57e8d8edf935d50bd69d65dd589b5f97d01abd361ba8017b7359cccfa6869c81be975cb31666d4f26422ed2189818dfb6a";
      };

    };
}
