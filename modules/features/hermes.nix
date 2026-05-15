{ ... }:
{
  flake.nixosModules.hermes =
    { config, pkgs, ... }:
    {
      services.hermes-agent = {
        enable = true;
        addToSystemPackages = true;
        user = "vir";
        group = "vir";
        createUser = false;
        workingDirectory = "/home/vir/git-repos";
        extraPackages = config.home-manager.users.vir.home.packages;
        extraDependencyGroups = [
          "messaging"
        ];
        extraPythonPackages = [
          pkgs.python313Packages.python-telegram-bot
        ];
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
          cwd = "/home/vir/git-repos";
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
