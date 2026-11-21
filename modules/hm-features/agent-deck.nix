{ inputs, ... }:
{
  flake.nixosModules.agent-deck-telegram-vir =
    {
      lib,
      secretsEnabled ? true,
      ...
    }:
    {
      sops.secrets.agent-deck-telegram-vir = lib.mkIf secretsEnabled {
        sopsFile = ../../secrets/agent-deck-vir.json;
        format = "json";
        key = "";
        owner = "vir";
        mode = "0400";
        restartUnits = [ "home-manager-vir.service" ];
      };
    };

  flake.homeModules.agent-deck =
    {
      config,
      lib,
      llm-agents,
      osConfig,
      pkgs,
      system,
      ...
    }:
    let
      python = pkgs.python3.withPackages (p: [ p.tomlkit ]);
      # Conductor bridge interpreter; agent-deck prefers conductor/venv and skips pip when deps import.
      # aiogram matches agent-deck's bridgePythonPins.
      bridgePython = pkgs.python3.withPackages (p: [
        p.toml
        (p.aiogram.overridePythonAttrs (old: rec {
          version = "3.31.0";
          src = pkgs.fetchFromGitHub {
            owner = "aiogram";
            repo = "aiogram";
            tag = "v${version}";
            hash = "sha256-bW21mt1Vs4nDHopvd/fW7okRVI124CntXOxv1QCFWaY=";
          };
        }))
      ]);
      configPath = lib.escapeShellArg "${config.xdg.configHome}/agent-deck/config.toml";
      legacyConfigPath = lib.escapeShellArg "${config.home.homeDirectory}/.agent-deck/config.toml";
      telegramPath = osConfig.sops.secrets."agent-deck-telegram-${config.home.username}".path or null;
      defaultConfig = (pkgs.formats.toml { }).generate "agent-deck-config.toml" {
        default_tool = "claude";
        theme = "dark";
        updates.check_enabled = false;
        claude.dangerous_mode = false;
        gemini.yolo_mode = true;
        security.auto_trust_folders = true;
        worktree.auto_cleanup = false;
        notifications.enabled = true;
        system_stats = {
          enabled = true;
          format = "compact";
        };
        ui = {
          sidebar_density = "compact";
          show_only_installed_tools = true;
        };
        global_search = {
          enabled = true;
          tier = "auto";
          recent_days = 90;
        };
        recall.enabled = true;
        instances.allow_multiple = true;
        conductor.heartbeat_interval = 15;
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

      xdg.dataFile."agent-deck/conductor/venv" = {
        source = bridgePython;
        force = true;
      };

      # Merge after Home Manager removes the old read-only symlink.
      home.activation.mergeAgentDeckConfig = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
        run ${python}/bin/python ${./agent-deck/merge-config.py} \
          ${defaultConfig} ${configPath} ${legacyConfigPath}${
            lib.optionalString (telegramPath != null) " ${lib.escapeShellArg telegramPath}"
          }
      '';
    };
}
