{ self, ... }:
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
      localModelsProvider = config.home-manager.users.vir.opencode.settings.providers.local-models;
    in
    {
      imports = [ self.nixosModules.localModels ];

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
          base_url = localModelsProvider.settings.baseURL;
          default = "qwen3.5-9b-abliterated";
          context_length = localModelsProvider.models."qwen3.5-9b-abliterated".limit.context;
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

      systemd.services.hermes-agent = {
        after = [ "local-models-proxy.socket" ];
        requires = [ "local-models-proxy.socket" ];
        serviceConfig.TimeoutStopSec = 210;
      };
    };
}
