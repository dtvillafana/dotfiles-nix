{ ... }:
{
  flake.homeModules.ai =
    { config, lib, ... }:
    lib.mkIf
      (builtins.elem config.home.username [
        "vir"
        "capcu"
      ])
      {
        home.file.".claude/CLAUDE.md".text = "@${config.home.homeDirectory}/.config/opencode/AGENTS.md\n";
        home.file.".claude/skills/search-emails/SKILL.md" = lib.mkIf (config.home.username == "capcu") {
          text = ''
            ---
            name: search-emails
            description: Search David's Microsoft 365 mailbox and read or download matching emails and attachments. Use for mailbox search, email reading, and attachment requests.
            ---

            # Microsoft 365 email

            Use the deferred `m365-attachment-reader-local` MCP tools (load them with
            `ToolSearch`) for `david.villafana@capcu.org`.

            - Use `search_messages` for keyword searches across the mailbox.
            - Use `list_recent_messages` only for newest-first requests. Filter its results
              client-side for dates or `isRead` when needed.
            - Use `read_email` for message metadata and short previews. When the full body
              is needed, call `read_email_body_chunk` starting at offset 0, read each
              chunk from `bodyText`, and continue with the returned `nextOffset` until
              `hasMore` is false.
            - Use `list_email_attachments` and `read_email_attachment` for attachments.
              The raw downloaded file is at `hostTempPath`.
            - Use `begin_auth` and `auth_status` if Graph authentication fails.

            ## Search workflow

            - Search meaningful terms separately; `OR` queries can hide relevant results.
            - Add a specific phrase or vendor query when broad searches are noisy.
            - Filter dates and unread status from returned metadata.
            - Verify candidates using sender, recipients, subject, and body preview.
            - "Sent only to me" means the `to` array is exactly
              `["david.villafana@capcu.org"]`.

            ## Attachments and sending

            Copy downloaded files from `hostTempPath` to the requested destination. Draft
            with `send_outlook_email`; set `send_now: true` only after explicit approval.
          '';
        };
        home.file.".config/opencode/AGENTS.md".text = ''
          # General Coding Instructions

          Follow the repository's existing conventions and make the smallest correct change.
          Format modified files and run the relevant checks before finishing.

          ## Nix

          - Use `nix fmt` for Nix formatting. If `nix fmt` is unavailable use `nixfmt`.
          - Prefer declarative Nix expressions and existing module options over imperative scripts.
          - Keep expressions simple; factor out bindings only when they improve clarity or avoid repetition.
          - Pin external inputs through the flake lock file. Do not use impure fetches.
          - Prompt the user to evaluate the affected flake or configuration after changes when practical instead of running the checks.

          ## Python

          - Target the project's configured Python version and dependency tooling.
          - Use the functional paradigm, dataclasses, pure functions, minimize mutable state and shadowing variables, etc. but no unnecessary functions that just pass their parameters to another function.
          - Use as many modern python type hints as possible
          - Keep functions focused and handle expected errors explicitly.

          ## Commands

          - when you try a command and the program is not available, then try again using `nix shell` to get the desired program before trying something else.
        '';
        home.file.".config/opencode/opencode.json".text = builtins.toJSON {
          "$schema" = "https://opencode.ai/config.json";
          plugin = [ "opencode-terminal-bell-notifier@0.2.0" ];
        };
      };
}
