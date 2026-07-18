{ ... }:
{
  flake.nixosModules.hermes =
    {
      config,
      llm-agents,
      system,
      ...
    }:
    let
      workingDirectory = "/home/vir/git-repos";
    in
    {
      services.hermes-agent = {
        enable = true;
        package = llm-agents.packages.${system}.hermes-agent;
        addToSystemPackages = true;
        user = "vir";
        group = "vir";
        createUser = false;
        inherit workingDirectory;
        extraPackages = config.home-manager.users.vir.home.packages;
        settings.model = {
          provider = "custom";
          base_url = "http://127.0.0.1:11434/v1";
          default = "qwen3.5:9b";
          context_length = 65536;
        };
        settings.max_turns = 100;
        settings.agent = {
          max_turns = 60;
          verbose = true;
        };
        settings.memory = {
          memory_enabled = true;
          user_profile_enabled = true;
        };
        settings.terminal = {
          cwd = workingDirectory;
          backend = "local";
          timeout = 180;
        };
        environmentFiles = [
          config.sops.secrets."hermes-env".path
        ];
      };

      systemd.services.hermes-agent.serviceConfig.TimeoutStopSec = 210;
    };
}
