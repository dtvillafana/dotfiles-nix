{ inputs, ... }:
{
  flake.homeModules.agent-deck =
    { llm-agents, system, ... }:
    {
      home.packages = [
        (llm-agents.packages.${system}.agent-deck.overrideAttrs (old: rec {
          version = "${old.version}-fork";
          src = inputs.agent-deck-src;
          ldflags = builtins.map (builtins.replaceStrings [ old.version ] [ version ]) old.ldflags;
        }))
      ];

      home.file.".config/agent-deck/config.toml".text = ''
        default_tool = "claude"
        theme = "dark"

        [tools.terminal]
        command = "zsh"
        icon = "⌨"

        [tools.opencode2]
        command = "opencode2"
        icon = "🌐"
        resume_flag = "--session"

        [claude]
        dangerous_mode = false

        [global_search]
        enabled = true
        tier = "auto"
        recent_days = 90

        [instances]
        allow_multiple = true
      '';
    };
}
