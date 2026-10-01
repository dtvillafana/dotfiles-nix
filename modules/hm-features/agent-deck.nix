{ ... }:
{
  flake.homeModules.agent-deck =
    { llm-agents, system, ... }:
    {
      home.packages = [ llm-agents.packages.${system}.agent-deck ];

      home.file.".config/agent-deck/config.toml".text = ''
        default_tool = "claude"
        theme = "dark"

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
