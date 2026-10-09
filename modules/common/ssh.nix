{ self, lib, ... }:
let
  publicKeys = import (self + /secrets/ssh-public-keys.nix);
  authorizedKeys = lib.concatMap builtins.attrValues (builtins.attrValues publicKeys);
in
{
  flake.nixosModules = {
    virHome.users.users.vir.openssh.authorizedKeys.keys = authorizedKeys;
    capcuHome.users.users.capcu.openssh.authorizedKeys.keys = authorizedKeys;
  };
}
