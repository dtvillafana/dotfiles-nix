{ inputs, ... }:
{
  flake.homeModules.agent-deck =
    {
      config,
      lib,
      llm-agents,
      pkgs,
      system,
      ...
    }:
    let
      python = pkgs.python3.withPackages (p: [ p.tomlkit ]);
      configPath = lib.escapeShellArg "${config.xdg.configHome}/agent-deck/config.toml";
      legacyConfigPath = lib.escapeShellArg "${config.home.homeDirectory}/.agent-deck/config.toml";
      defaultConfig = (pkgs.formats.toml { }).generate "agent-deck-config.toml" {
        default_tool = "claude";
        theme = "dark";
        updates.check_enabled = false;
        claude.dangerous_mode = false;
        global_search = {
          enabled = true;
          tier = "auto";
          recent_days = 90;
        };
        recall.enabled = true;
        instances.allow_multiple = true;
      };
    in
    {
      home.packages = [
        (llm-agents.packages.${system}.agent-deck.overrideAttrs (old: rec {
          version = "${old.version}-fork";
          src = inputs.agent-deck-src;
          vendorHash = "sha256-cuiMn9Pd4VQD4KpodLe+Sw+6P+Vou7aCm4NlAmR9Jfc=";
          doCheck = false;
          ldflags = map (builtins.replaceStrings [ old.version ] [ version ]) old.ldflags;
        }))
      ];

      # Merge after Home Manager removes the old read-only symlink.
      home.activation.mergeAgentDeckConfig = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
        run ${python}/bin/python ${./agent-deck/merge-config.py} \
          ${defaultConfig} ${configPath} ${legacyConfigPath}
      '';
    };
}
