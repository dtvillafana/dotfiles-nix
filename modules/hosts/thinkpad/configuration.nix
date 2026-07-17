{ self, ... }:
{
  flake.nixosModules.thinkpadConfig =
    { ... }:
    {
      imports = [ self.nixosModules.androidTools ];
    };
}
