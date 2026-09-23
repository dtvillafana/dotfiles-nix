{ ... }:
let
  mkM365AttachmentReader =
    pkgs:
    pkgs.buildNpmPackage {
      pname = "m365-attachment-reader-mcp-local";
      version = "0.2.0-unstable-2026-09-23";
      src = pkgs.fetchFromGitHub {
        owner = "dtvillafana";
        repo = "Outlook-Email-MCP";
        rev = "ca026870343a80419a7acd86e534282e243bc5fb";
        hash = "sha256-Ooa2uTpp1PAO3eY5oiQvwrkf10AxmdPd46+hSm+8hZM=";
      };
      npmDepsHash = "sha256-bRFxD56mZk3E9psqdqXtGuDN8AG//O4wj2iu7+rbifI=";
      dontNpmBuild = true;
      meta.mainProgram = "m365-attachment-reader-mcp-local";
    };

  mcpEnv = {
    M365_AUTO_OPEN_BROWSER = "true";
    M365_CLIENT_ID = "94f0e6f2-1e6e-4227-8db0-6e2c6597eb2f";
    M365_MCP_DATA_DIR = "/home/capcu/.local/state/m365-attachment-reader-mcp-local";
    M365_TENANT_ID = "284e75a7-9343-4b85-8e22-0b774e0b4298";
  };
in
{
  perSystem =
    { pkgs, ... }:
    {
      packages.m365-attachment-reader = mkM365AttachmentReader pkgs;
    };

  flake.nixosModules.hermesM365Email =
    {
      lib,
      pkgs,
      secretsEnabled ? true,
      ...
    }:
    let
      m365AttachmentReader = mkM365AttachmentReader pkgs;
    in
    {
      services.hermes-agent = lib.mkIf secretsEnabled {
        mcpServers.m365-attachment-reader-local = {
          command = lib.getExe m365AttachmentReader;
          env = mcpEnv;
        };
        settings.tools.tool_search.enabled = "off";
      };
    };
}
