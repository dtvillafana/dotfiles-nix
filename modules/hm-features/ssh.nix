{ ... }:
{
  flake.homeModules.ssh =
    { lib, osConfig, ... }:
    {
      programs.ssh = {
        enable = true;
        enableDefaultConfig = false;
        settings = {
          "vps" = lib.hm.dag.entryAnywhere {
            Hostname = "104.207.135.195";
            IdentityFile = "${osConfig.sops.secrets.git_vps.path}";
            User = "root";
            Port = 4455;
          };
          "org" = lib.hm.dag.entryAfter [ "vps" ] {
            Hostname = "172.234.200.63";
            IdentityFile = "${osConfig.sops.secrets.ssh_nix_key.path}";
            User = "vir";
            Port = 22;
          };
          "*" = lib.hm.dag.entryAfter [ "org" ] {
            IdentityFile = "${osConfig.sops.secrets.ssh_nix_key.path}";
          };
        };
      };
    };
}
