{ ... }:
{
  flake.homeModules.ssh =
    { lib, osConfig, ... }:
    {
      programs.ssh = {
        enable = true;
        enableDefaultConfig = false;
        matchBlocks = {
          "vps" = lib.hm.dag.entryAnywhere {
            hostname = "104.207.135.195";
            identityFile = "${osConfig.sops.secrets.git_vps.path}";
            user = "root";
            port = 4455;
          };
          "org" = lib.hm.dag.entryAfter [ "vps" ] {
            hostname = "172.234.200.63";
            identityFile = "${osConfig.sops.secrets.ssh_nix_key.path}";
            user = "vir";
            port = 22;
          };
          "*" = lib.hm.dag.entryAfter [ "org" ] {
            identityFile = "${osConfig.sops.secrets.ssh_nix_key.path}";
          };
        };
      };
    };
}
