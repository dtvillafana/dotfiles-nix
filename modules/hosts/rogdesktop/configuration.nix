{ self, inputs, ... }:
{
  flake.nixosModules.rogdesktopConfig =
    {
      config,
      hermes-agent,
      lib,
      pkgs,
      ...
    }:
    let
      xsessionInitExtra = ''
        xset -dpms
        xset s off
        xset s noblank
      '';
    in
    {
      imports = [
        self.nixosModules.androidTools
        self.nixosModules.rogdesktopHardware
      ];

      services.xserver.videoDrivers = [ "nvidia" ];

      nixpkgs.config.cudaCapabilities = [ "6.1" ];

      hardware.nvidia = {
        package = config.boot.kernelPackages.nvidiaPackages.legacy_580;
        modesetting.enable = true;
        open = false;
      };

      hardware.graphics.enable = true;

      programs.steam.enable = true;

      services.ollama.loadModels = lib.mkForce [ "qwen3.5:9b" ];

      sops.secrets."hermes-env".restartUnits = [
        "hermes-agent.service"
        "hermes-webui.service"
      ];

      services.hermes-agent = {
        enable = true;
        package = hermes-agent.packages.${pkgs.stdenv.hostPlatform.system}.default;
        container.enable = false;
        addToSystemPackages = true;
        user = "vir";
        group = "vir";
        createUser = false;
        workingDirectory = "/home/vir/git-repos";
        extraPackages = config.home-manager.users.vir.home.packages;
        environmentFiles = [ config.sops.secrets."hermes-env".path ];
        environment = {
          API_SERVER_HOST = "127.0.0.1";
          API_SERVER_PORT = "8642";
        };
        settings = {
          toolsets = [ "all" ];
          platforms.api_server.enabled = true;
          model = {
            provider = "custom";
            base_url = "http://127.0.0.1:11434/v1";
            default = "qwen3.5:9b";
            context_length = 65536;
          };
          max_turns = 100;
          agent = {
            max_turns = 60;
            verbose = true;
            tool_use_enforcement = true;
            intent_ack_continuation = true;
          };
          memory = {
            memory_enabled = true;
            user_profile_enabled = true;
          };
          terminal = {
            cwd = "/home/vir/git-repos";
            backend = "local";
            timeout = 180;
          };
        };
      };

      services.hermes-webui = {
        enable = true;
        user = "vir";
        group = "vir";
        stateDir = "/home/vir/.hermes/webui";
        hermesHome = "${config.services.hermes-agent.stateDir}/.hermes";
        agent.package = config.services.hermes-agent.package;
        environmentFiles = [ config.sops.secrets."hermes-env".path ];
        extraEnvironment.HERMES_WEBUI_CHAT_BACKEND = "legacy";
      };

      systemd.services.hermes-agent = {
        after = [ "ollama-model-loader.service" ];
        requires = [ "ollama-model-loader.service" ];
        environment.HOME = lib.mkForce "/home/vir";
        restartTriggers = [
          (pkgs.writeText "hermes-agent-gateway-config" (
            builtins.toJSON {
              inherit (config.services.hermes-agent) environment settings;
            }
          ))
        ];
        serviceConfig.TimeoutStopSec = 210;
      };

      systemd.services.hermes-webui = {
        after = [ "hermes-agent.service" ];
        requires = [ "hermes-agent.service" ];
      };

      home-manager.users = builtins.listToAttrs (
        map
          (username: {
            name = username;
            value.xsession.initExtra = xsessionInitExtra;
          })
          [
            "vir"
            "capcu"
          ]
      );
    };
}
