{ self, ... }:
{
  flake.nixosModules.systemSecrets =
    {
      lib,
      secretsEnabled ? true,
      ...
    }:
    {
      sops = lib.mkIf secretsEnabled {
        defaultSopsFile = self + /secrets/secrets.json;
        defaultSopsFormat = "json";
      };
    };
}
