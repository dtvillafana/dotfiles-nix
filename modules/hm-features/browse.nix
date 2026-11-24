{ inputs, self, ... }:
{
  perSystem =
    { pkgs, system, ... }:
    {
      packages = pkgs.lib.optionalAttrs (system == "x86_64-linux") {
        browse = pkgs.callPackage ../../packages/browse.nix {
          inherit (inputs) browse-cli-src;
        };
      };
    };

  flake.homeModules.browse =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      package = self.packages.${pkgs.stdenv.hostPlatform.system}.browse;
      port = config.browse.relayPort;
      browse =
        if port == null then
          package
        else
          pkgs.writeShellScriptBin "browse" ''
            export OPENCODE_BROWSER_PORT="''${OPENCODE_BROWSER_PORT:-${toString port}}"
            exec ${lib.getExe package} "$@"
          '';
      browseExe = lib.getExe' browse "browse";
      browseExtension = {
        id = "mfnicocicmmlkpjnaffgihfjhdgjkdjg";
      };
    in
    {
      key = "dotfiles-nix-browse";
      options.browse.relayPort = lib.mkOption {
        type = lib.types.nullOr lib.types.port;
        default = null;
        description = "Pin Browse to a dedicated relay port for this user.";
      };
      config = {
        home.packages = [ browse ];
        programs.brave.extensions = [ browseExtension ];
        programs.chromium.extensions = [ browseExtension ];
        opencode.settings.mcp.servers.browse = {
          type = "local";
          command = [
            browseExe
            "mcp"
          ];
          codemode = false;
        };

        # Claude owns this mutable file; preserve other servers and credentials.
        home.activation.configureClaudeBrowseMcp =
          lib.hm.dag.entryAfter
            [
              "writeBoundary"
              "configureClaudeMcp"
              "configureClaudeNixosMcp"
            ]
            ''
              if [ -n "''${DRY_RUN_CMD:-}" ]; then
                echo "Would configure the Claude Code browse MCP server"
              else
                (
                  set -eu
                  umask 077
                  claude_config="$HOME/.claude.json"
                  temporary_config=$(mktemp "$HOME/.claude.json.XXXXXX")
                  trap 'rm -f "$temporary_config"' EXIT
                  source_config="$claude_config"
                  if [ ! -e "$source_config" ]; then
                    source_config=${pkgs.writeText "empty-claude-config.json" "{}"}
                  fi
                  ${lib.getExe pkgs.jq} --arg command "${browseExe}" \
                    '.mcpServers.browse = {type: "stdio", command: $command, args: ["mcp"]}' \
                    "$source_config" > "$temporary_config"
                  mv "$temporary_config" "$claude_config"
                )
              fi
            '';
      };
    };
}
