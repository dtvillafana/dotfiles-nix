{ self, inputs, ... }:
{
  flake.nixosModules.ssh =
    { home-manager, config, ... }:
    {
      home-manager.users.vir =
        { pkgs, ... }:
        {
          programs.ssh = {
            enable = true;
            enableDefaultConfig = false;
            matchBlocks = {
              "vps" = home-manager.lib.hm.dag.entryAnywhere {
                hostname = "104.207.135.195";
                identityFile = "${config.sops.secrets.git_vps.path}";
                user = "root";
                port = 4455;
              };
              "org" = home-manager.lib.hm.dag.entryAfter [ "vps" ] {
                hostname = "172.234.200.63";
                identityFile = "${config.sops.secrets.ssh_nix_key.path}";
                user = "vir";
                port = 22;
              };
              "*" = home-manager.lib.hm.dag.entryAfter [ "org" ] {
                identityFile = "${config.sops.secrets.ssh_nix_key.path}";
              };
            };
          };
        };
    };
}
