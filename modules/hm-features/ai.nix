{ inputs, ... }:
{
  flake.homeModules.ai =
    {
      config,
      lib,
      llm-agents,
      osConfig,
      pkgs,
      secretsEnabled ? true,
      system,
      ...
    }:
    let
      openBrowserUse = pkgs.callPackage ../../packages/open-browser-use.nix { };
      socketDir = "$XDG_RUNTIME_DIR/open-browser-use";
      openBrowserUseCommand = ''
        socket_dir="${socketDir}"
        case "''${1:-}" in
          call|cdp|claim-tab|finalize-tabs|history|info|mcp|move-mouse|name-session|navigate|open-tab|ping|run|set-file-chooser-files|tabs|turn-ended|user-tabs|wait-file-chooser)
            command="$1"
            shift
            exec ${openBrowserUse}/bin/open-browser-use "$command" --socket-dir "$socket_dir" "$@"
            ;;
          *)
            exec ${openBrowserUse}/bin/open-browser-use "$@"
            ;;
        esac
      '';
      openBrowserUseCli = pkgs.symlinkJoin {
        name = "open-browser-use-wrapped";
        paths = [
          (pkgs.writeShellScriptBin "open-browser-use" openBrowserUseCommand)
          (pkgs.writeShellScriptBin "obu" openBrowserUseCommand)
        ];
      };
      openBrowserUseHost = pkgs.writeShellScript "open-browser-use-host" ''
        exec ${openBrowserUse}/bin/open-browser-use host --socket-dir "${socketDir}"
      '';
      servicedeskPackage =
        inputs.zoho-desk-mcp-server.packages.${pkgs.stdenv.hostPlatform.system}.default;
      nativeMessagingManifest = builtins.toJSON {
        name = "com.ifuryst.open_browser_use.extension";
        description = "Open Browser Use Chrome native messaging host";
        path = openBrowserUseHost;
        type = "stdio";
        allowed_origins = [ "chrome-extension://bgjoihaepiejlfjinojjfgokghnodnhd/" ];
      };
      # OpenCode invokes the configured shell as `shell -c <command>`, which is
      # non-interactive and skips ~/.zshrc. This wrapper loads that startup so
      # `!` and shell-tool commands see the same aliases, functions, PATH, and
      # direnv environment as an interactive zsh.
      opencodeZsh = pkgs.writeShellScriptBin "opencode-zsh" ''
        set -eu
        zsh=${lib.getExe pkgs.zsh}
        if [ "''${1-}" != -c ]; then
          exec "$zsh" "$@"
        fi
        shift
        exec "$zsh" -c '
          emulate -L zsh
          setopt aliases
          export POWERLEVEL9K_INSTANT_PROMPT=off
          export POWERLEVEL9K_DISABLE_INSTANT_PROMPT=true
          {
            source "''${ZDOTDIR:-$HOME}/.zshrc"
          } >/dev/null 2>&1
          if (( $+commands[direnv] )); then
            direnv_export=$(direnv export zsh || true)
            [[ -n $direnv_export ]] && eval "$direnv_export"
          fi
          eval "$1"
        ' -- "''${1-}"
      '';
      # Appended to the shared global instructions. Claude imports that file, so
      # both tools see the sops paths under /run/secrets, like the Gitea token.
      agentRuntimeSecrets = lib.genAttrs config.agentRuntimeSecrets (
        name: osConfig.sops.secrets.${name}.path
      );
      runtimeSecretsText =
        let
          lines = lib.mapAttrsToList (name: path: "- `${name}`: `${path}`") agentRuntimeSecrets;
        in
        ''
          # Runtime secrets

          These secrets are decrypted for this user and readable at runtime under `/run/secrets`, the same way as other secrets such as the Gitea token. Read a file only when the task needs that credential. Do not print, log, copy, or commit the secret value.

          ${lib.concatStringsSep "\n" lines}
        '';
    in
    {
      options.opencode.settings = lib.mkOption {
        type = lib.types.attrs;
        default = { };
        description = "Additional OpenCode V2 configuration settings.";
      };

      options.agentRuntimeSecrets = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "SOPS secret names this user can read. Their runtime paths are merged into the Claude and OpenCode global instructions.";
      };

      config = lib.mkMerge [
        {
          home.packages = [
            llm-agents.packages.${system}.claude-code
            llm-agents.packages.${system}.grok
            llm-agents.packages.${system}.handy
            llm-agents.packages.${system}.herdr
            llm-agents.packages.${system}.opencode2
            openBrowserUseCli
          ];

          xdg.configFile = {
            "BraveSoftware/Brave-Browser/NativeMessagingHosts/com.ifuryst.open_browser_use.extension.json".text =
              nativeMessagingManifest;
            "chromium/NativeMessagingHosts/com.ifuryst.open_browser_use.extension.json".text =
              nativeMessagingManifest;
            "google-chrome/NativeMessagingHosts/com.ifuryst.open_browser_use.extension.json".text =
              nativeMessagingManifest;
          };
        }
        (lib.mkIf
          (builtins.elem config.home.username [
            "vir"
            "capcu"
          ])
          {
            home.file.".claude/CLAUDE.md".text =
              "@${config.home.homeDirectory}/.config/opencode/AGENTS.md\n"
              + lib.optionalString (config.home.username == "capcu") ''

                ## Email

                When composing, drafting, or sending email whose recipients are all
                `@capcu.org` addresses, end the body with a small footer that says
                exactly: Sent by Claude. Do not add that footer if any To/Cc/Bcc
                recipient is outside `@capcu.org`.
              '';
            home.file.".claude/hooks/append-sent-by-claude.py" = lib.mkIf (config.home.username == "capcu") {
              executable = true;
              source = pkgs.replaceVars ./ai/claude/hooks/append-sent-by-claude.py {
                python313 = pkgs.python313;
              };
            };
            home.activation.configureClaudeEmailFooter = lib.mkIf (config.home.username == "capcu") (
              lib.hm.dag.entryAfter [ "writeBoundary" ] ''
                config="$HOME/.claude/settings.json"
                hook="${config.home.homeDirectory}/.claude/hooks/append-sent-by-claude.py"
                matcher='mcp__.*__(send_outlook_email|reply_outlook_email|outlook_send_mail|outlook_send_email|outlook_send_draft)$'
                mkdir -p "$HOME/.claude"
                if [ ! -e "$config" ]; then
                  echo '{}' >"$config"
                fi
                temporary_config=$(mktemp "$HOME/.claude/settings.json.XXXXXX")
                ${pkgs.jq}/bin/jq \
                  --arg command "$hook" \
                  --arg matcher "$matcher" \
                  '.hooks.PreToolUse = (
                    ((.hooks.PreToolUse // []) | map(select((.hooks // []) | all(.command != $command))))
                    + [{ matcher: $matcher, hooks: [{ type: "command", command: $command }] }]
                  )' \
                  "$config" >"$temporary_config"
                mv "$temporary_config" "$config"
              ''
            );
            home.file.".claude/skills/search-emails/SKILL.md" = lib.mkIf (config.home.username == "capcu") {
              source = ./ai/claude/skills/search-emails/SKILL.md;
            };
            home.file.".claude/skills/compile-activity-report/SKILL.md" =
              lib.mkIf (config.home.username == "capcu" && secretsEnabled)
                {
                  source = pkgs.replaceVars ./ai/claude/skills/compile-activity-report/SKILL.md {
                    gitea_llm_token = osConfig.sops.secrets.gitea_llm_token.path;
                  };
                };
            home.file.".claude/skills/daily-tasks/SKILL.md" =
              lib.mkIf (config.home.username == "capcu" && secretsEnabled)
                {
                  source = pkgs.replaceVars ./ai/claude/skills/daily-tasks/SKILL.md {
                    gitea_llm_token = osConfig.sops.secrets.gitea_llm_token.path;
                  };
                };
            home.file.".config/opencode/AGENTS.md".text =
              builtins.readFile ./ai/opencode/AGENTS.md
              + lib.optionalString (config.agentRuntimeSecrets != [ ]) ''

                ${runtimeSecretsText}
              '';
            home.file.".config/opencode/cli.json" = {
              force = true;
              text = builtins.toJSON {
                "$schema" = "https://opencode.ai/v2/cli.json";
                attention = {
                  enabled = true;
                  notifications = true;
                  sound = true;
                  volume = 0.4;
                };
                keybinds = {
                  "agent.cycle" = "tab";
                  "agent.cycle.reverse" = "shift+tab";
                };
                theme = {
                  name = "catppuccin-macchiato";
                };
              };
            };
            home.file.".grok/config.toml".text = ''
              [marketplace]
              default_skills_installs_purged = true
              official_marketplace_auto_installed = true

              [[marketplace.sources]]
              name = "xAI Official"
              git = "https://github.com/xai-org/plugin-marketplace.git"

              [ui]
              vim_mode = true
            '';
            home.file.".grok/config.toml".enable = false;
            home.activation.installGrokConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
              config="$HOME/.grok/config.toml"
              mkdir -p "$HOME/.grok"
              if [ -L "$config" ]; then
                rm "$config"
              fi
              install -m 0644 "${config.home.file.".grok/config.toml".source}" "$config"
            '';
            home.file.".config/opencode/opencode.json".text =
              let
                subagentRule = effect: resource: {
                  action = "subagent";
                  inherit resource effect;
                };
                exploreDescription = ''
                  Fast agent specialized for exploring codebases. Use this when you need to quickly find files by patterns (eg. "src/components/**/*.tsx"), search code for keywords (eg. "API endpoints"), or answer questions about the codebase (eg. "how do API endpoints work?"). When calling this agent, specify the desired thoroughness level: "quick" for basic searches, "medium" for moderate exploration, or "very thorough" for comprehensive analysis across multiple locations and naming conventions.
                '';
                exploreSystem = ''
                  You are a file search specialist. You excel at thoroughly navigating and exploring codebases.

                  Your strengths:
                  - Rapidly finding files using glob patterns
                  - Searching code and text with powerful regex patterns
                  - Reading and analyzing file contents

                  Guidelines:
                  - Use Glob for broad file pattern matching
                  - Use Grep for searching file contents with regex
                  - Use Read when you know the specific file path you need to read
                  - Adapt your search approach based on the thoroughness level specified by the caller
                  - Return file paths as absolute paths in your final response
                  - For clear communication, avoid using emojis
                  - Do not create any files, or run bash commands that modify the user's system state in any way

                  Complete the user's search request efficiently and report your findings clearly.
                '';
                planSystem = ''
                  You are operating in plan mode. Investigate the request and produce a concrete implementation plan. Do not implement the plan.

                  - Do not create, edit, delete, rename, or format project files.
                  - Do not run commands or tools that change files, Git state, services, infrastructure, workflows, credentials, or remote systems.
                  - Use read-only inspection to understand the repository and requirements.
                  - Ask clarifying questions when important requirements are unresolved.
                  - Your final response must be an actionable plan covering relevant files, implementation steps, validation, risks, and unresolved decisions.
                  - Never treat a request to build, fix, create, or implement something as permission to leave plan mode. Tell the user to switch to a build agent before implementation.
                '';
                generalDescription = "General-purpose agent for researching complex questions and executing multi-step tasks. Use this agent to execute multiple units of work in parallel.";
                explorePermissions = [
                  {
                    action = "*";
                    resource = "*";
                    effect = "deny";
                  }
                  {
                    action = "grep";
                    resource = "*";
                    effect = "allow";
                  }
                  {
                    action = "glob";
                    resource = "*";
                    effect = "allow";
                  }
                  {
                    action = "webfetch";
                    resource = "*";
                    effect = "allow";
                  }
                  {
                    action = "websearch";
                    resource = "*";
                    effect = "allow";
                  }
                  {
                    action = "read";
                    resource = "*";
                    effect = "allow";
                  }
                  {
                    action = "external_directory";
                    resource = "*";
                    effect = "ask";
                  }
                  {
                    action = "external_directory";
                    resource = "~/git-repos/orgfiles/*";
                    effect = "allow";
                  }
                  {
                    action = "external_directory";
                    resource = "~/git-repos/dotfiles-nix/*";
                    effect = "allow";
                  }
                  {
                    action = "subagent";
                    resource = "*";
                    effect = "deny";
                  }
                ];
                generalPermissions = [
                  {
                    action = "question";
                    resource = "*";
                    effect = "deny";
                  }
                  {
                    action = "subagent";
                    resource = "*";
                    effect = "deny";
                  }
                ];
                planFilePermissions = [
                  {
                    action = "edit";
                    resource = "*";
                    effect = "deny";
                  }
                  {
                    action = "edit";
                    resource = "~/.opencode/plan/*";
                    effect = "allow";
                  }
                  {
                    action = "external_directory";
                    resource = "~/.opencode/plan/*";
                    effect = "allow";
                  }
                  {
                    action = "shell";
                    resource = "*";
                    effect = "deny";
                  }
                ];
                mkFamilySubagentPerms = explore: general: [
                  (subagentRule "deny" "*")
                  (subagentRule "allow" explore)
                  (subagentRule "allow" general)
                ];
                mkPlanSubagentPerms = explore: [
                  (subagentRule "deny" "*")
                  (subagentRule "allow" explore)
                ];
                mkExplore = model: {
                  inherit model;
                  mode = "subagent";
                  description = exploreDescription;
                  system = exploreSystem;
                  permissions = explorePermissions;
                };
                mkGeneral = model: {
                  inherit model;
                  mode = "subagent";
                  description = generalDescription;
                  permissions = generalPermissions;
                };
                mkBuild =
                  {
                    model,
                    explore,
                    general,
                    description,
                  }:
                  {
                    inherit model description;
                    mode = "primary";
                    permissions = mkFamilySubagentPerms explore general;
                  };
                mkPlan =
                  {
                    model,
                    explore,
                    description,
                  }:
                  {
                    inherit model description;
                    mode = "primary";
                    system = planSystem;
                    permissions = planFilePermissions ++ mkPlanSubagentPerms explore;
                  };
              in
              builtins.toJSON (
                lib.recursiveUpdate {
                  "$schema" = "https://opencode.ai/config.json";
                  update = "disable";
                  shell = "${opencodeZsh}/bin/opencode-zsh";
                  agents = {
                    explore = {
                      model = "openai/gpt-6-luna#medium";
                      mode = "subagent";
                    };
                    general = {
                      model = "openai/gpt-6-luna#max";
                      mode = "subagent";
                    };
                    "grok-explore" = mkExplore "xai/grok-build-0.1";
                    "grok-general" = mkGeneral "xai/grok-4.7#low";
                    "openai-explore" = mkExplore "openai/gpt-6-luna#medium";
                    "openai-general" = mkGeneral "openai/gpt-6-luna#max";
                    "grok-build" = mkBuild {
                      model = "xai/grok-4.7#high";
                      explore = "grok-explore";
                      general = "grok-general";
                      description = "The default agent. Executes tools based on configured permissions.";
                    };
                    "grok-plan" = mkPlan {
                      model = "xai/grok-4.7#high";
                      explore = "grok-explore";
                      description = "Read-only agent for exploring the codebase and planning work before implementation. Cannot edit code files.";
                    };
                    "openai-build" = mkBuild {
                      model = "openai/gpt-6.1-sol#high";
                      explore = "openai-explore";
                      general = "openai-general";
                      description = "The default agent. Executes tools based on configured permissions.";
                    };
                    "openai-plan" = mkPlan {
                      model = "openai/gpt-6.1-sol#high";
                      explore = "openai-explore";
                      description = "Read-only agent for exploring the codebase and planning work before implementation. Cannot edit code files.";
                    };
                  };
                  providers.openai = {
                    websocket = true;
                    compaction.mode = "provider";
                  };
                  permissions = [
                    {
                      action = "read";
                      resource = "*.env";
                      effect = "ask";
                    }
                    {
                      action = "read";
                      resource = "**secret**";
                      effect = "ask";
                    }
                    {
                      action = "read";
                      resource = "**/secrets/**";
                      effect = "ask";
                    }
                    {
                      action = "shell";
                      resource = "git push *";
                      effect = "ask";
                    }
                    {
                      action = "external_directory";
                      resource = "~/git-repos/orgfiles/*";
                      effect = "allow";
                    }
                    {
                      action = "external_directory";
                      resource = "~/git-repos/dotfiles-nix/*";
                      effect = "allow";
                    }
                  ];
                  references.dotfiles = {
                    path = "~/git-repos/dotfiles-nix";
                    description = "NixOS and home-manager flake for this machine: hosts, home modules, OpenCode/AI config, packages, and secrets layout. Use when changing system or user config.";
                  };
                  mcp.servers = {
                    open_browser_use = {
                      type = "local";
                      command = [
                        "${openBrowserUseCli}/bin/obu"
                        "mcp"
                      ];
                      timeout = {
                        catalog = 30000;
                      };
                    };
                  }
                  // lib.optionalAttrs (config.home.username == "capcu" && secretsEnabled) {
                    servicedesk = {
                      type = "local";
                      command = [
                        "${pkgs.writeShellScript "servicedesk-mcp-server" ''
                          set -euo pipefail
                          set -a
                          source "${osConfig.sops.templates.servicedesk-mcp-env.path}"
                          set +a
                          exec ${lib.getExe servicedeskPackage}
                        ''}"
                      ];
                      timeout = {
                        catalog = 30000;
                      };
                    };
                  };
                } config.opencode.settings
              );
          }
        )
      ];
    };
}
