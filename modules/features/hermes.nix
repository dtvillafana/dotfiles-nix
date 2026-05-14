{ ... }:
{
  flake.nixosModules.hermes =
    { config, pkgs, ... }:
    {
      services.hermes-agent = {
        enable = true;
        addToSystemPackages = true;
        extraDependencyGroups = [
          "messaging"
        ];
        extraPythonPackages = [
          pkgs.python312Packages.python-telegram-bot
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
        environmentFiles = [
          config.sops.secrets."hermes-env".path
        ];
      };

      systemd.services.hermes-agent.serviceConfig.TimeoutStopSec = 210;
    };
}
