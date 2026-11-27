{ lib, ... }:
let
  publicKeys = {
    rogdesktop = {
      vir = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKCuP12yjE+XepyjLqYn1sYBN8Y6iGUmPTrtjghQ0Ppb vir@rogdesktop";
      capcu = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEJOgAbezqTwOQZnkad6A+qoqE1wtOjLhHRYY4vYxTyD capcu@rogdesktop";
    };
    capcuDell.capcu = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEqSKqaPhlOzf9qXtN3du9AORQMhs1+J9IV/+6XNTWyW capcu@capcuDell";
    hp-xeon.vir = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFd8fptfc5wduMomf9hJKQD2zRZ2v7QV/GGiwf44BPKB vir@hp-xeon";
    thinkpad.vir = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPsK25Aq8wXHm8zY+cl8S1eQ4zEQZXJF5srvFO+RlRQM vir@thinkpad";
  };
  authorizedKeys = lib.concatMap builtins.attrValues (builtins.attrValues publicKeys);
in
{
  flake.nixosModules = {
    virHome.users.users.vir.openssh.authorizedKeys.keys = authorizedKeys;
    capcuHome.users.users.capcu.openssh.authorizedKeys.keys = authorizedKeys;
  };
}
