{ self, inputs, ... }:
{
  flake.homeModules.workAi =
    {
      config,
      lib,
      osConfig,
      pkgs,
      secretsEnabled ? true,
      ...
    }:
    {
      imports = [ self.homeModules.ai ];

      config = lib.mkMerge [
        {
          home.file.".claude/CLAUDE.md".text = ''
            ## Email

            When composing, drafting, or sending email whose recipients are all
            `@capcu.org` addresses, end the body with a small footer that says
            exactly: Sent by Claude. Do not add that footer if any To/Cc/Bcc
            recipient is outside `@capcu.org`.
          '';
          home.file.".claude/hooks/append-sent-by-claude.py" = {
            executable = true;
            source = pkgs.replaceVars ./ai/claude/hooks/append-sent-by-claude.py {
              python313 = pkgs.python313;
            };
          };
          home.activation.configureClaudeEmailFooter = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
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
              --arg allow "mcp__servicedesk__servicedesk_close_request" \
              '.hooks.PreToolUse = (
                ((.hooks.PreToolUse // []) | map(select((.hooks // []) | all(.command != $command))))
                + [{ matcher: $matcher, hooks: [{ type: "command", command: $command }] }]
              )
              | .permissions.allow = (
                (.permissions.allow // []) as $allowed
                | if $allowed | index($allow) then $allowed else $allowed + [$allow] end
              )' \
              "$config" >"$temporary_config"
            mv "$temporary_config" "$config"
          '';
          home.file.".claude/skills/search-emails/SKILL.md".source =
            ./ai/claude/skills/search-emails/SKILL.md;
        }
        (lib.mkIf secretsEnabled {
          home.file.".claude/skills/compile-activity-report/SKILL.md".source =
            pkgs.replaceVars ./ai/claude/skills/compile-activity-report/SKILL.md
              {
                gitea_llm_token = osConfig.sops.secrets.gitea_llm_token.path;
              };
          home.file.".claude/skills/daily-tasks/SKILL.md".source =
            pkgs.replaceVars ./ai/claude/skills/daily-tasks/SKILL.md
              {
                gitea_llm_token = osConfig.sops.secrets.gitea_llm_token.path;
              };
          opencode.settings.mcp.servers.metabase = {
            type = "remote";
            url = "https://metabase.capcu.org/api/metabase-mcp";
            oauth = false;
            headers."X-API-Key" = "{file:${osConfig.sops.secrets.metabase_api_key.path}}";
          };
          opencode.settings.mcp.servers.servicedesk = {
            type = "local";
            command = [
              "${pkgs.writeShellScript "servicedesk-mcp-server" ''
                set -euo pipefail
                set -a
                source "${osConfig.sops.templates.servicedesk-mcp-env.path}"
                set +a
                exec ${lib.getExe inputs.zoho-desk-mcp-server.packages.${pkgs.stdenv.hostPlatform.system}.default}
              ''}"
            ];
            timeout.catalog = 30000;
          };
        })
      ];
    };
}
