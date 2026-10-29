{ self, inputs, ... }:
{
  flake.nixosModules.hermes =
    {
      config,
      lib,
      pkgs,
      secretsEnabled ? true,
      ...
    }:
    let
      agent = config.services.hermes-agent;
      localModelsProvider =
        config.home-manager.users.${agent.user}.opencode.settings.providers.local-models;
      localProfileDir = "${agent.stateDir}/.hermes/profiles/local";
      localModel = agent.settings.model // {
        api_key = "local-no-auth";
      };
      # mcp_servers and tools come from modules such as hermesM365Email, which
      # write them onto services.hermes-agent.settings. Include them so the
      # local profile keeps the same MCP servers across rebuilds.
      localProfileExtra = lib.filterAttrs (
        name: _:
        name == "mcp_servers" || name == "tools"
      ) agent.settings;
      localProfileConfig = (pkgs.formats.yaml { }).generate "hermes-local-config.yaml" ({
        inherit (agent.settings)
          custom_providers
          max_turns
          agent
          memory
          terminal
          toolsets
          ;
        model = localModel;
        fallback_model = [ ];
        fallback_providers = [ ];
        # Pin background calls too, rather than allowing their automatic cloud fallback.
        auxiliary =
          lib.genAttrs
            [
              "vision"
              "compression"
              "skills_hub"
              "approval"
              "review"
              "mcp"
              "title_generation"
              "memory_query_rewrite"
              "tts_audio_tags"
              "triage_specifier"
              "kanban_decomposer"
              "profile_describer"
              "goal_judge"
              "curator"
              "monitor"
              "background_review"
              "moa_reference"
              "moa_aggregator"
            ]
            (_: {
              provider = localModel.provider;
              model = localModel.default;
              inherit (localModel) base_url api_key;
            });
      } // localProfileExtra);
      localProfileEnv = pkgs.writeText "hermes-local.env" ''
        # No cloud credentials: this profile uses the machine's local-model proxy.
        OPENAI_BASE_URL=${localModel.base_url}
        OPENAI_API_KEY=local-no-auth
      '';
    in
    {
      key = "dotfiles-nix-hermes";
      imports = [
        inputs.hermes-agent.nixosModules.default
        inputs.hermes-webui.nixosModules.default
        self.nixosModules.localModels
      ];

      config = lib.mkIf secretsEnabled {
        # Managed profile configuration; sessions and memory remain writable and separate.
        # Select with `hermes --profile local` without changing the default profile.
        systemd.tmpfiles.rules = [
          "d ${agent.stateDir}/.hermes/profiles 2770 ${agent.user} ${agent.group} - -"
          "d ${localProfileDir} 2770 ${agent.user} ${agent.group} - -"
          "L+ ${localProfileDir}/config.yaml - - - - ${localProfileConfig}"
          "L+ ${localProfileDir}/.env - - - - ${localProfileEnv}"
        ];

        services.hermes-agent = {
          enable = true;
          package = inputs.hermes-agent.packages.${pkgs.stdenv.hostPlatform.system}.default;
          container.enable = false;
          addToSystemPackages = true;
          group = agent.user;
          createUser = false;
          extraPackages = config.home-manager.users.${agent.user}.home.packages;
          environment = {
            API_SERVER_HOST = "127.0.0.1";
            API_SERVER_PORT = "8642";
          };
          settings = {
            toolsets = [ "all" ];
            platforms.api_server.enabled = true;
            model = {
              provider = "custom:local-models";
              base_url = localModelsProvider.settings.baseURL;
              default = "qwen3.5-9b-abliterated";
              context_length = localModelsProvider.models."qwen3.5-9b-abliterated".limit.context;
            };
            custom_providers = [
              {
                name = "Local Models";
                base_url = localModelsProvider.settings.baseURL;
                api_key = "local-no-auth";
                model = "qwen3.5-9b-abliterated";
                models = lib.mapAttrs (_: model: {
                  context_length = model.limit.context;
                }) localModelsProvider.models;
              }
            ];
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
              backend = "local";
              timeout = 180;
            };
          };
        };

        services.hermes-webui = {
          enable = true;
          inherit (agent) user group environmentFiles;
          stateDir = "/home/${agent.user}/.hermes/webui";
          hermesHome = "${agent.stateDir}/.hermes";
          agent.package = agent.package;
        };

        systemd.services.hermes-agent = {
          after = [ "local-models-proxy.socket" ];
          requires = [ "local-models-proxy.socket" ];
          environment.HOME = lib.mkForce "/home/${agent.user}";
          restartTriggers = [
            (pkgs.writeText "hermes-agent-gateway-config" (
              builtins.toJSON {
                inherit (agent) environment settings;
              }
            ))
          ];
          serviceConfig.TimeoutStopSec = 210;
        };

        systemd.services.hermes-webui = {
          after = [ "hermes-agent.service" ];
          requires = [ "hermes-agent.service" ];
        };
      };
    };

  flake.nixosModules.hermesCapcuDell =
    {
      config,
      lib,
      pkgs,
      secretsEnabled ? true,
      ...
    }:
    {
      imports = [ self.nixosModules.hermes ];

      environment.systemPackages = [
        inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.hermes-desktop
      ];

      sops.secrets."hermes-env-capcu" = lib.mkIf secretsEnabled {
        sopsFile = self + /secrets/hermes-dell.yaml;
        format = "yaml";
        owner = "capcu";
        group = "capcu";
        restartUnits = [
          "hermes-agent.service"
          "hermes-webui.service"
        ];
      };

      services.hermes-agent = lib.mkIf secretsEnabled {
        user = "capcu";
        workingDirectory = "/home/capcu";
        environmentFiles = [ config.sops.secrets."hermes-env-capcu".path ];
      };
      services.hermes-webui = lib.mkIf secretsEnabled {
        extraEnvironment = {
          HERMES_WEBUI_CHAT_BACKEND = "gateway";
          HERMES_WEBUI_GATEWAY_BASE_URL = "http://${config.services.hermes-agent.environment.API_SERVER_HOST}:${config.services.hermes-agent.environment.API_SERVER_PORT}";
        };
      };
    };

  flake.nixosModules.hermesRogdesktop =
    {
      config,
      lib,
      secretsEnabled ? true,
      ...
    }:
    {
      imports = [ self.nixosModules.hermes ];

      sops.secrets."hermes-env" = lib.mkIf secretsEnabled {
        sopsFile = self + /secrets/hermes-rog.yaml;
        format = "yaml";
        owner = "vir";
        group = "vir";
        restartUnits = [
          "hermes-agent.service"
          "hermes-webui.service"
        ];
      };

      services.hermes-agent = lib.mkIf secretsEnabled {
        user = "vir";
        workingDirectory = "/home/vir/git-repos";
        environmentFiles = [ config.sops.secrets."hermes-env".path ];
        settings.terminal.cwd = "/home/vir/git-repos";
      };
      services.hermes-webui = lib.mkIf secretsEnabled {
        extraEnvironment.HERMES_WEBUI_CHAT_BACKEND = "legacy";
      };
    };
}
