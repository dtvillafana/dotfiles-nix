{ self, ... }:
{
  perSystem =
    { pkgs, system, ... }:
    {
      packages = pkgs.lib.optionalAttrs (system == "x86_64-linux") {
        protonmail-bridge-mcp = pkgs.callPackage ../../packages/protonmail-bridge-mcp { };
      };
    };

  flake.nixosModules.protonMailCap765 =
    {
      lib,
      secretsEnabled ? true,
      ...
    }:
    let
      sopsFile = self + /secrets/proton-bridge-cap765.json;
      credentialsPath = "/run/secrets/proton-bridge-cap765";
    in
    lib.mkIf secretsEnabled {
      sops.secrets.proton-bridge-cap765 = lib.mkIf (builtins.pathExists sopsFile) {
        inherit sopsFile;
        format = "json";
        key = "";
        owner = "vir";
        mode = "0400";
        path = credentialsPath;
      };
      home-manager.users.vir.opencode.settings.mcp.servers.protonmail_bridge.environment.PROTON_BRIDGE_CREDENTIALS_FILE =
        credentialsPath;
    };

  flake.homeModules.protonMail =
    { lib, pkgs, ... }:
    let
      server = self.packages.${pkgs.stdenv.hostPlatform.system}.protonmail-bridge-mcp;
    in
    {
      key = "dotfiles-nix-proton-mail";
      imports = [ self.homeModules.ai ];
      home.packages = [
        server
        pkgs.protonmail-bridge
      ];
      home.file.".config/opencode/skills/proton-mail/SKILL.md".source = ./proton-mail/SKILL.md;
      opencode.settings.mcp.servers.protonmail_bridge = {
        type = "local";
        command = [ (lib.getExe server) ];
        timeout = {
          startup = 120000;
          execution = 120000;
        };
      };
    };
}
