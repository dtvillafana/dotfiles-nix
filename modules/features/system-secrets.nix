{ self, ... }:
{
  flake.nixosModules.systemSecrets =
    {
      config,
      lib,
      secretsEnabled ? true,
      ...
    }:
    let
      profileUsers = lib.filter (user: builtins.hasAttr user config.users.users) [
        "vir"
        "capcu"
      ];
    in
    {
      sops = lib.mkIf secretsEnabled (
        {
          defaultSopsFile = self + /secrets/secrets.json;
          defaultSopsFormat = "json";
        }
        // lib.optionalAttrs (profileUsers != [ ]) {
          age.sshKeyPaths = map (user: "/home/${user}/.ssh/id_ed25519") profileUsers;
        }
      );
    };
}
