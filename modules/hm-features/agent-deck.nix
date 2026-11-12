{ inputs, ... }:
{
  flake.homeModules.agent-deck =
    { llm-agents, system, ... }:
    {
      home.packages = [
        (llm-agents.packages.${system}.agent-deck.overrideAttrs (old: rec {
          version = "${old.version}-fork";
          src = inputs.agent-deck-src;
          vendorHash = "sha256-8d56v5csbdGaQku2LR7Twy2fKoXBVPKN9KPHdsithjg=";
          doCheck = false;
          ldflags = builtins.map (builtins.replaceStrings [ old.version ] [ version ]) old.ldflags;
        }))
      ];

      home.file.".config/agent-deck/config.toml".text = ''
        default_tool = "claude"
        theme = "dark"

        [updates]
        check_enabled = false

        [tools.terminal]
        command = "zsh"
        icon = "⌨"

        [claude]
        dangerous_mode = false

        [global_search]
        enabled = true
        tier = "auto"
        recent_days = 90

        [recall]
        enabled = true

        [instances]
        allow_multiple = true
      '';
    };
}
