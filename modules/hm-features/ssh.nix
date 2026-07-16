{ ... }:
{
  flake.homeModules.ssh =
    {
      config,
      lib,
      osConfig,
      ...
    }:
    let
      username = config.home.username;
      gitVpsKey = osConfig.sops.secrets."git_vps_${username}".path;
      sshNixKey = osConfig.sops.secrets."ssh_nix_key_${username}".path;
    in
    {
      programs.ssh = {
        enable = true;
        enableDefaultConfig = false;
        settings = {
          "vps" = lib.hm.dag.entryAnywhere {
            Hostname = "104.207.135.195";
            IdentityFile = "${gitVpsKey}";
            User = "root";
            Port = 4455;
          };
          "org" = lib.hm.dag.entryAfter [ "vps" ] {
            Hostname = "172.234.200.63";
            IdentityFile = "${sshNixKey}";
            User = "vir";
            Port = 22;
          };
          "*" = lib.hm.dag.entryAfter [ "org" ] {
            IdentityFile = "${sshNixKey}";
          };
        };
      };
    };
}
