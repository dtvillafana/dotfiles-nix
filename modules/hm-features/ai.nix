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
             description: Search David's Outlook/Microsoft 365 mailbox (david.villafana@capcu.org) via the locally-installed m365-attachment-reader-local MCP server, and optionally download matching emails' attachments to a local folder. Use when asked to "find emails about X", "search my email/inbox for Y", "look for invoices/receipts", "download attachments from emails about Z", or any other mailbox search/download request.
            ---

             # Searching Outlook mail via the m365-attachment-reader-local MCP server

             Home Manager registers the local stdio MCP server
             (`m365-attachment-reader-local`) in `~/.claude.json` during activation. It
             talks to Microsoft Graph on behalf of `david.villafana@capcu.org` and exposes
             these tools (load via `ToolSearch` if not already available -- they're deferred):

            - `search_messages` -- **use this for almost everything.** Full-text search
              (subject + body + sender + attachments) via Microsoft Graph's native
              `$search`, unbounded by recency. `folder` defaults to `"all"` (whole
              mailbox). `top` accepts up to 2000 and pages through `@odata.nextLink`
              automatically to satisfy it (not capped at a single 50-item page). This was
              hand-added to `server.mjs`; it does not exist in the upstream repo -- see
              "If `search_messages` is missing" below.
            - `list_recent_messages` -- lists the newest messages in one folder (default
              inbox), filtering client-side on subject/sender substring only. `top` also
              accepts up to 2000 and pages through `@odata.nextLink` to satisfy it. Still
              prefer `search_messages` for anything keyword-driven -- this tool has no
              relevance ranking, it's purely newest-first, so it's best for "what came in
              today/this week" or "give me the last N regardless of content" asks.
            - `read_email` -- full subject/from/to/cc/date/body text for one message ID.
            - `list_email_attachments` -- attachment metadata (id, name, size) for one
              message ID.
            - `read_email_attachment` -- downloads + locally parses one attachment. The
              parsed/extracted text comes back in the tool response, but the **raw file
              is also written to `hostTempPath`** (an OS temp path, since this is a local
              process on this same machine) -- that's what to `cp` into a real
              destination, not something reconstructed from the response text.
            - `send_outlook_email` -- sends (or drafts) mail with local file attachments.
            - `begin_auth` / `auth_status` -- device-code login flow if the cached MSAL
              token has expired and Graph calls start failing with an auth error.

            ## Search workflow

            1. **Never rely on a single `OR`-combined query as the only pass.** `search_messages`
               ranks by relevance against whatever candidate pool the query produces, and
               that pool is *not* the union of each term's own top results -- combining
               terms with `OR` (e.g. `"invoice OR receipt"`) changes the ranking in ways
               that can bump a message completely out of the top 50 even though it would
               have placed comfortably if searched on its own. Confirmed case: `"Your n8n
               receipt"` ranked ~29th of 50 for `query: "receipt"` alone, but did not
               appear anywhere in the top 50 for `query: "invoice OR receipt"`. **Always
               run each meaningful term as its own separate query** (`"invoice"`, then
               `"receipt"`, then vendor-specific follow-ups) rather than trusting one
               combined pass -- especially before telling the user something wasn't found.
            2. If you know roughly what you're looking for, also run a targeted,
               specific query (e.g. `"Google Workspace invoice"`) -- narrow queries surface
               low-frequency messages that broad ones bury.
            3. Microsoft Graph `$search` syntax: `term1 OR term2`, quoted exact phrases,
               and you can scope with `subject:"..."` / `body:"..."` if needed. No
               `$filter`/date-range can be combined with `$search` in this tool as
               written -- if the user wants a specific date cutoff, run the search, then
               filter the returned `receivedDateTime` values yourself.
            4. **"Sent only to me" means the `to` array is exactly
               `["david.villafana@capcu.org"]`** -- nothing else. Watch for false
               positives from:
               - Department/shared aliases (`ITDept@capcu.org`, `EmailAdmins@capcu.org`,
                 etc.) -- mail addressed to these lands in the inbox but is not "to David"
                 personally.
               - Messages where David is only on `cc`, or one of many `to` recipients.
               - Internal reply/forward threads that merely *mention* a keyword (e.g. an
                 internal escalation thread with "Receipt" in the subject about a
                 member's issue, not David's own purchase).
            5. Cross-check candidates before treating them as real matches -- a keyword
               hit in a marketing email, a Teams notification, or an unrelated internal
               thread is common noise. Read the `bodyPreview` / `fromAddress` before
               committing to a match.

            ## Downloading attachments to a real folder

            For each matching message:

            1. `list_email_attachments` to get attachment IDs.
            2. `read_email_attachment` for each -- note the `hostTempPath` in the
               response.
            3. `cp` from `hostTempPath` to the destination directory (e.g.
               `~/Downloads/<descriptive-folder>/`), renaming with a date/sender prefix
               for clarity since the source filenames are often generic (`invoice.pdf`,
               `receipt.pdf`).
            4. Optionally write a small `.txt` alongside with subject/from/to/date/
               webLink for provenance -- the tool's `read_email` doesn't reliably surface
               full body text back to this session (only `bodyPreview`/metadata came
               through in practice), so don't rely on it for a full-body dump.

            ## Sending what you found

            `send_outlook_email` defaults to saving a draft (`send_now: false`) -- only
            pass `send_now: true` after the user has explicitly approved the subject/body
            text. Always show the draft body and attachment list in chat first unless the
            user has said otherwise.

            ## If `search_messages` is missing

            If only `list_recent_messages`, `list_email_attachments`, `read_email`,
            `read_email_attachment`, and `send_outlook_email` show up (no
            `search_messages`), the server was reinstalled/reset and the patch was lost.
            Re-add it: open `~/git-repos/Claude-MCP-Read-Email-Attachments/server.mjs`,
            find the `list_recent_messages` `registerAliases(...)` block, and insert a
            `search_messages` tool right after it that builds a Graph query like:

            ```
            ''${messageCollectionUrl(mailbox, folder)}?$search=''${encodeURIComponent('"' + query + '"')}&$select=id,subject,receivedDateTime,hasAttachments,from,toRecipients,ccRecipients,bodyPreview&$top=<=100
            ```

            called via `graphGetJson(url, { ConsistencyLevel: "eventual" })` -- `graphGetJson`
            takes an optional second `extraHeaders` argument for this. If `top` needs to
            exceed one page, loop on the response's `@odata.nextLink` (a fully-formed URL
            -- just re-fetch it directly, no need to re-add `$search`) until enough items
            are collected or the link runs out; see `searchMessagesHandler` in the
            current `server.mjs` for the exact pattern already in place. Run
            `node --check server.mjs` to verify syntax, then note that **MCP tool lists
            are fixed at session start** -- the new tool won't be callable until a fresh
            conversation is opened (restarting the stdio subprocess mid-session isn't
            possible from within a session).
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
      };
}
