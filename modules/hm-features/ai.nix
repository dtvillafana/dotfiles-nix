{ inputs, ... }:
{
  flake.homeModules.ai =
    {
      config,
      lib,
      osConfig,
      pkgs,
      secretsEnabled ? true,
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
    in
    {
      options.opencode.settings = lib.mkOption {
        type = lib.types.attrs;
        default = { };
        description = "Additional OpenCode V2 configuration settings.";
      };

      config = lib.mkMerge [
        {
          home.packages = [ openBrowserUseCli ];

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
              text = ''
                #!${pkgs.python313}/bin/python3
                from __future__ import annotations

                import json
                import sys
                from typing import Any

                FOOTER = "Sent by Claude"
                FOOTER_MARKER = "sent by claude"
                BODY_KEYS = ("body", "content", "htmlBody", "html_body", "text")
                RECIPIENT_KEYS = (
                    "to",
                    "cc",
                    "bcc",
                    "to_recipients",
                    "cc_recipients",
                    "bcc_recipients",
                    "toRecipients",
                    "ccRecipients",
                    "bccRecipients",
                )


                def already_has_footer(body: str) -> bool:
                    return FOOTER_MARKER in body.lower()


                def looks_like_html(body: str, body_type: str) -> bool:
                    if body_type.upper() == "HTML":
                        return True
                    stripped = body.lstrip().lower()
                    return stripped.startswith("<") and any(
                        token in stripped for token in ("html", "<p", "<div", "<br", "<body")
                    )


                def append_footer(body: str, html: bool) -> str:
                    if already_has_footer(body):
                        return body
                    if html:
                        footer = (
                            f'<p style="margin-top:1.5em;font-size:11px;color:#888;">{FOOTER}</p>'
                        )
                        return body.rstrip() + footer if body.strip() else footer
                    if body.strip():
                        return f"{body.rstrip()}\n\n{FOOTER}"
                    return FOOTER


                def body_type_of(tool_input: dict[str, Any]) -> str:
                    value = tool_input.get("bodyType") or tool_input.get("body_type") or ""
                    return str(value)


                def split_addresses(value: Any) -> list[str]:
                    if value is None:
                        return []
                    if isinstance(value, list):
                        addresses: list[str] = []
                        for item in value:
                            addresses.extend(split_addresses(item))
                        return addresses
                    if isinstance(value, dict):
                        for key in ("address", "email"):
                            nested = value.get(key)
                            if isinstance(nested, str):
                                return split_addresses(nested)
                        return split_addresses(value.get("emailAddress"))
                    if not isinstance(value, str):
                        return []
                    return [
                        part.strip()
                        for part in value.replace(";", ",").split(",")
                        if part.strip()
                    ]


                def normalize_address(address: str) -> str:
                    lowered = address.lower().strip()
                    start = lowered.rfind("<")
                    end = lowered.rfind(">")
                    if 0 <= start < end:
                        return lowered[start + 1 : end].strip()
                    return lowered


                def is_capcu_address(address: str) -> bool:
                    return normalize_address(address).endswith("@capcu.org")


                def recipients_are_internal(tool_input: dict[str, Any]) -> bool:
                    addresses: list[str] = []
                    for key in RECIPIENT_KEYS:
                        addresses.extend(split_addresses(tool_input.get(key)))
                    return bool(addresses) and all(
                        is_capcu_address(address) for address in addresses
                    )


                def main() -> None:
                    try:
                        data = json.load(sys.stdin)
                    except json.JSONDecodeError:
                        raise SystemExit(0)

                    tool_input = data.get("tool_input")
                    if not isinstance(tool_input, dict):
                        raise SystemExit(0)
                    if not recipients_are_internal(tool_input):
                        raise SystemExit(0)

                    updated = dict(tool_input)
                    body_type = body_type_of(updated)
                    changed = False

                    for key in BODY_KEYS:
                        value = updated.get(key)
                        if not isinstance(value, str):
                            continue
                        new_value = append_footer(value, looks_like_html(value, body_type))
                        if new_value != value:
                            updated[key] = new_value
                            changed = True
                            break

                    if not changed:
                        existing = updated.get("body")
                        existing_body = existing if isinstance(existing, str) else ""
                        new_value = append_footer(
                            existing_body, looks_like_html(existing_body, body_type)
                        )
                        if new_value != existing_body:
                            updated["body"] = new_value
                            changed = True

                    if not changed:
                        raise SystemExit(0)

                    json.dump(
                        {
                            "hookSpecificOutput": {
                                "hookEventName": "PreToolUse",
                                "updatedInput": updated,
                            }
                        },
                        sys.stdout,
                    )


                if __name__ == "__main__":
                    main()
              '';
            };
            home.activation.configureClaudeEmailFooter =
              lib.mkIf (config.home.username == "capcu")
                (
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
              text = ''
                ---
                name: search-emails
                description: Search David's Microsoft 365 mailbox and read or download matching emails and attachments. Use for mailbox search, email reading, attachment requests, and sending or replying to Outlook mail.
                ---

                # Microsoft 365 email

                Use the deferred `m365-attachment-reader-local` MCP tools (load them with
                `ToolSearch`) for `david.villafana@capcu.org`.

                - Use `search_messages` for keyword searches across the mailbox.
                - Use `list_recent_messages` only for newest-first requests. Filter its results
                  client-side for dates or `isRead` when needed. Set
                  `onlyWithAttachments: false` when looking up mail to read or reply to.
                - Use `read_email` with the `messageId` from list/search. When the full body
                  is needed, call `read_email_body_chunk` starting at offset 0, read each
                  chunk from `bodyText`, and continue with the returned `nextOffset` until
                  `hasMore` is false.
                - Use `list_email_attachments` and `read_email_attachment` for attachments.
                  The raw downloaded file is at `hostTempPath`.
                - Use `begin_auth` and `auth_status` if Graph authentication fails.

                Typical chain — copy `messageId` through every step:
                1. `search_messages` or `list_recent_messages`
                2. `read_email` with that `messageId`
                3. `reply_outlook_email` with the **same** `messageId` (never
                   `send_outlook_email` for a reply)

                ## Search workflow

                - Search meaningful terms separately; `OR` queries can hide relevant results.
                - Add a specific phrase or vendor query when broad searches are noisy.
                - Filter dates and unread status from returned metadata.
                - Verify candidates using sender, recipients, subject, and body preview.
                - "Sent only to me" means the `to` array is exactly
                  `["david.villafana@capcu.org"]`.

                ## Attachments and sending

                Copy downloaded files from `hostTempPath` to the requested destination.

                - New mail: draft with `send_outlook_email`; set `send_now: true` only after
                  explicit approval.
                - Replies: after `read_email`, call `reply_outlook_email` with that same
                  `messageId` so the reply stays in the Outlook conversation. Do not use
                  `send_outlook_email` with an "RE:" subject — that starts a new thread.
                  Default is a draft; set `send_now: true` only after explicit approval.
                  Use `replyAll: true` when the original had multiple recipients.
                - Drafts: `send_outlook_email` / `reply_outlook_email` return `draftId`.
                  Use `list_outlook_drafts` to find drafts, `edit_outlook_draft` to change
                  subject/body/recipients or add attachments, and `delete_outlook_draft`
                  to discard. Both edit and delete refuse sent mail. Confirm before delete.

                If every To/Cc/Bcc address ends in `@capcu.org`, end the body with a small
                footer that says exactly: Sent by Claude. Omit that footer when any
                recipient is outside `@capcu.org`.
              '';
            };
            home.file.".claude/skills/compile-activity-report/SKILL.md" =
              lib.mkIf (config.home.username == "capcu" && secretsEnabled)
                {
                  text = ''
                    ---
                    name: compile-activity-report
                    description: Compile a report of David's completed/in-progress work over a date range, pulled from Gitea PR history, ServiceDesk tickets, Outlook email, and his capcu.org work notes. Use when asked for an activity summary, status report, or "what have I done since X" to give to a supervisor or management.
                    ---

                    # Compile activity report

                    Produces a report of work completed (and, where relevant, in progress) over a
                    requested date range, for david.villafana@capcu.org. Default range if none is
                    given: since the 1st of the current month.

                    ## 1. Gather sources

                    Run these in parallel — they're independent.

                    **Gitea (ccugitea.capcu.org)** — one of four co-equal sources; covers
                    code-tracked work at PR-level detail.
                    - Read the API token from
                      `${osConfig.sops.secrets.gitea_llm_token.path}` into `GITEA_TOKEN` for
                      each command (shell state doesn't persist between Bash calls). Never echo
                      the raw token into a tool result or copy it to another file.
                    - Use the **global** search endpoint instead of iterating repos one by one:
                      `GET /api/v1/repos/issues/search?type=pulls&state=closed&since=<ISO8601>&limit=50&page=N`
                      — paginate with `page` until a page returns fewer than `limit` items;
                      `X-Total-Count` header gives the grand total.
                    - Filter client-side: `pull_request.merged == true`, `user.login ==
                      "dvillafana"`, and `pull_request.merged_at >= <range start>`.
                    - Group by `repository.full_name`; sort each group by `merged_at`.

                    **Direct commits to the default branch across the CapCU org** — also capture
                    code David pushed straight to `master`/`main` without a PR (hotfixes, config
                    bumps, automation commits); these never appear in the PR search above.
                    - Enumerate org repos: `GET /api/v1/orgs/capcu/repos?limit=50&page=N`,
                      paginating until a short page. Skip archived repos unless the range
                      predates their archival.
                    - For each repo, list default-branch commits in the window:
                      `GET /api/v1/repos/capcu/<repo>/commits?sha=<default_branch>&since=<ISO8601>&until=<ISO8601>&limit=50`
                      — use the repo's actual `default_branch` from the repos listing. Repos with
                      no commits in the window come back empty fast; skip them.
                    - Keep commits whose `author.login == "dvillafana"` or whose
                      `commit.author.email == "david.villafana@capcu.org"`.
                    - Drop commits already covered by a merged PR above (match by SHA against the
                      PR's commit range) and drop pure-merge commits with no standalone change,
                      so nothing is double-counted.
                    - Group by repo; summarize what the commits changed as a short bulleted list
                      with the date span — don't dump every commit message.

                    **ServiceDesk (servicedesk MCP)** — co-equal
                    source for helpdesk work. Gitea does not see tickets, notes, or closures.
                    - Call the `servicedesk` MCP tools (names start with `servicedesk_`). Do not
                      spawn the server yourself and do not read `config.json` — it holds the
                      technician API key.
                    - David's technician identity is email `david.villafana@capcu.org`. Resolve
                      with `servicedesk_find_user_by_email` or
                      `servicedesk_list_active_assigned_requests` (`technician_email`) if a
                      tool wants an id or display name.
                    - Open / still assigned (in progress):
                      `servicedesk_list_active_assigned_requests` with
                      `technician_email` = `david.villafana@capcu.org`. Raise
                      `max_assigned_requests` while `list_info.has_more_rows` is true. Keep
                      tickets whose `last_updated_time` (or notes/history) fall in the report
                      window; older idle assignments can still appear under in-progress if they
                      remain on his queue.
                    - Closed in the window: `servicedesk_list_requests` with `status` =
                      `Closed`, `sort_by` = `last_updated_time`, `sort_order` = `desc`. Paginate
                      with `start_index` until rows fall before the range start. Keep those
                      whose `technician` is David and whose `completed_time` / `closed_time` /
                      `last_updated_time` is inside the range. ServiceDesk often rejects
                      combined status+technician filters, so filter client-side. If the closed
                      list is huge, `servicedesk_api_request` GET `requests` with
                      technician search_criteria, then drop non-closed / out-of-range rows.
                    - Other activity by David in the window, even when he is not the current
                      assignee: notes he added, status/assignment changes, resolutions, and
                      tasks. For tickets updated in-range, call
                      `servicedesk_list_request_notes` and/or `servicedesk_get_request_full`.
                      For a timeline, `servicedesk_api_request` GET `requests/<id>/history` and
                      keep events in the window whose actor is David.
                      `servicedesk_list_tasks` for tasks he owns. `servicedesk_search_requests`
                      for his name only when the assigned/closed lists look incomplete.
                    - Read-only for this report — do not create, update, close, or comment.
                    - Tickets often contain member PII. Never quote account numbers, SSNs,
                      passwords, or full descriptions — request id, subject, status, and a
                      one-line sanitized takeaway only.
                    - If the MCP is missing or fails, say so in the report rather than silently
                      omitting ServiceDesk.

                    **Email (Outlook, via m365-attachment-reader-local)** — co-equal source, not
                    just corroboration. Gitea only sees code; plenty of completed work (vendor
                    coordination, non-code project milestones, decisions, meetings-turned-status)
                    lives only in email and must be reported as its own completed/in-progress
                    item, not merely used to annotate a Gitea entry. Launch as a background
                    general-purpose agent (see `search-emails` skill for tool details) so it runs
                    while you work the Gitea data. Ask it to search for status-update emails,
                    go-live/deployed notices, and named-project threads — both ones matching
                    repos/themes already found in Gitea, and independent ones that may not have
                    any corresponding code — and to report back project name, date,
                    sender/recipients, and a one-sentence takeaway distinguishing *completed*
                    from *in-progress/waiting-on-vendor*. Skip routine noise (meeting invites,
                    automated alerts).

                    **Work notes** — `~/git-repos/orgfiles/work/capcu/capcu.org` — a fourth
                    co-equal source, not just enrichment text. Some completed or in-progress work
                    (vendor/account setup, planning, non-code tasks) is tracked only here and
                    must show up as its own initiative even with nothing to merge it into. An
                    Emacs org-mode file using `#+TODO: TODO MEET CALL WAITING EVENT | DONE
                    CANCELED DELEGATED`. Read it directly (it's a local file, not an API) and
                    look for:
                    - Headings/items whose state changed to `DONE` within the report window, or
                      whose surrounding notes/timestamps place them in that window — report
                      these as completed initiatives in their own right if they don't map to a
                      Gitea/email/ServiceDesk item.
                    - `WAITING`/`DELEGATED` items relevant to initiatives also seen in Gitea,
                      email, or ServiceDesk — useful for the "in progress" section, and worth
                      including on their own even without a counterpart in the other sources.
                    - Project names and one-line descriptions to enrich vague Gitea repo names
                      where they do overlap.

                    **This file contains live production credentials, IPs, and passwords for core
                    banking system integrations (SymXchange, jXChange, etc.).** Never quote,
                    copy, or include any credential/IP/password from it into the report, into an
                    Artifact, or into memory — extract only project names, statuses, and plain
                    descriptions of what a project does.

                    **Teams**: no Teams-access tool is available by default. If asked to include
                    Teams and none is available, say so explicitly in the final report rather
                    than silently omitting it.

                    ## 2. Merge sources — none is subordinate to another

                    Gitea, ServiceDesk, email, and the org file are four co-equal sources of
                    truth. Merge them into one initiative list rather than treating any one as
                    a footnote on another:

                    - Where items from two or more sources clearly map to the same initiative,
                      merge into one entry and let each source fill in what the others lack
                      (email/org file give business context and vendor/task status; Gitea gives
                      what was actually built; ServiceDesk gives ticket status, closures, and
                      requester-facing work).
                    - Where an item from any single source has **no corresponding activity in
                      the others** (e.g. a closed ServiceDesk request with no PR, a
                      vendor-coordination milestone from email, a non-code task from the org
                      file, a repo with no email or org-file trace), include it as its own
                      initiative — do not drop it just because it isn't corroborated elsewhere.
                      Most real work will only show up in one source.
                    - If sources conflict on status (e.g. email or the org file implies
                      still-open work on something Gitea shows fully merged), trust the more
                      recent/specific signal and say so rather than silently picking one.
                    - Anything dated **before** the requested range start should be excluded even
                      if related evidence mentions it in passing — call this out in a note
                      rather than silently dropping context (e.g. "X completed just before this
                      window, excluded here").
                    - Keep a strict line between **Complete** and **In progress / waiting on
                      vendor** — do not let an in-progress initiative read as finished.

                    ## 3. Pick the audience and build the report

                    Ask (or infer from context) who the report is for:

                    - **Management / non-technical supervisor or C-suite**: lead with a 2–3
                      sentence "bottom line" executive summary. Group by business outcome
                      (security/compliance, member-service impact, operational efficiency,
                      reliability) — not by repo or technical system name. Avoid engineering
                      jargon (Kubernetes, Helm, SOPS, Ansible/AWX internals, API/endpoint
                      details) — translate to what changed for the business. Use a
                      Complete/In-progress status pill per section (green/amber, not the page's
                      main accent color — semantic color is separate from brand accent). Put
                      repo-level/PR-count detail in a collapsed `<details>` block at the bottom
                      for backup, not the main flow.
                    - **Technical / peer audience**: repo names, PR titles, and counts can stay
                      in the main body; still separate completed vs. in-progress clearly.

                    Build it as a published Artifact:
                    - Load the `artifact-design` skill before writing HTML — this is a
                      utilitarian memo/report treatment (real typographic hierarchy, a considered
                      neutral+accent palette, restrained flourishes), not an editorial/landing
                      page treatment.
                    - Design both light and dark themes per the skill's token pattern.
                    - Include a stat row (3–4 numbers) sized to the audience: raw PR / direct-commit / repo / ticket counts
                      for a technical reader, outcome-shaped counts (e.g. "processes automated",
                      "tickets closed", "initiatives in progress") for a management reader.
                    - Republish to the same file path / same `url` on revision so the link stays
                      stable across follow-up edits (e.g. re-scoping the date range, changing
                      audience).

                    ## 4. After delivering

                    Save anything durable to memory: new project/initiative names, stakeholders,
                    and in-progress status snapshots (mark these as time-sensitive — they decay
                    fast, note the as-of date). Do not save the report content itself or PR
                    counts to memory; those are cheap to regenerate from Gitea and go stale
                    immediately.
                  '';
                };
            home.file.".claude/skills/daily-tasks/SKILL.md" =
              lib.mkIf (config.home.username == "capcu" && secretsEnabled)
                {
                  text = ''
                    ---
                    name: daily-tasks
                    description: Assemble David's prioritized list of what to work on today (or a stated day/week), merging open Gitea PRs and issues, ServiceDesk tickets, capcu.org work-note deadlines, and actionable email. Use for "what should I work on today", "my tasks for today", "what's on my plate", or standup prep.
                    ---

                    # Daily task list

                    Assembles a prioritized "what to work on now" list for
                    david.villafana@capcu.org. This is the forward-looking mirror of
                    `compile-activity-report` (which looks backward at finished work). Default
                    horizon: **today**. The user may widen it ("this week", "next few days").

                    ## 1. Gather sources — in parallel, they are independent

                    **Gitea (ccugitea.capcu.org)** — open code work.
                    - Read the API token from
                      `${osConfig.sops.secrets.gitea_llm_token.path}` into `GITEA_TOKEN` for
                      each command (shell state does not persist between Bash calls). Never echo
                      the raw token into a tool result or copy it to another file.
                    - Open PRs authored by / involving David:
                      `GET /api/v1/repos/issues/search?type=pulls&state=open&limit=50`
                    - PRs where David's review is requested:
                      `GET /api/v1/repos/issues/search?type=pulls&state=open&review_requested=true&limit=50`
                    - Open issues assigned to David:
                      `GET /api/v1/repos/issues/search?type=issues&state=open&assigned=true&limit=50`
                    - For any PR that looks close to landing, fetch
                      `GET /api/v1/repos/<owner>/<repo>/pulls/<n>` and note `draft`,
                      `mergeable`, `updated_at`. Treat draft / unmergeable / long-stale
                      (`updated_at` older than ~2 weeks) branches as "idle", not active work.
                    - `user.login == "dvillafana"` is David. Other logins (e.g. `cmercer`)
                      matter here only when their PR is awaiting his review.

                    **ServiceDesk (servicedesk MCP)** — open
                    tickets.
                    - Call the `servicedesk` MCP tools (names start with `servicedesk_`). Do not
                      spawn the server yourself and do not read `config.json` — it holds the
                      technician API key.
                    - David's technician identity is email `david.villafana@capcu.org`.
                    - Primary queue: `servicedesk_list_active_assigned_requests` with
                      `technician_email` = `david.villafana@capcu.org` (raise
                      `max_assigned_requests` while `list_info.has_more_rows` is true). These
                      non-closed assigned tickets are what he should work.
                    - Also call `servicedesk_list_open_requests` (paginate `start_index` while
                      `list_info.has_more_rows`) and keep unassigned or group tickets that
                      belong on his plate. Do not dump the entire org-wide open queue.
                    - For priority, due date, or the last note on a ticket that might be
                      today's work, `servicedesk_get_request` or
                      `servicedesk_get_request_full`.
                    - Read-only for this list — do not create, update, close, pick up, or
                      comment unless David asked to act on a ticket.
                    - Tickets often contain member PII. Never quote account numbers, SSNs,
                      passwords, or full descriptions — request id, subject, status, priority,
                      due date, and a one-line sanitized summary only.
                    - If the MCP is missing or fails, say so and continue with Gitea + org +
                      email rather than silently omitting tickets.

                    **Work notes** — `~/git-repos/orgfiles/work/capcu/capcu.org` — read it
                    directly (local file, not an API). Emacs org-mode, `#+TODO: TODO MEET CALL
                    WAITING EVENT | DONE CANCELED DELEGATED`. Extract:
                    - Active-state headings (`TODO/MEET/CALL/WAITING/EVENT`) with their priority
                      cookie — `[#A]` highest through `[#D]`/none lowest.
                    - Every `SCHEDULED:` / `DEADLINE:` timestamp. Parse the `<YYYY-MM-DD ...>`
                      date relative to today:
                      + date before today and state not DONE/CANCELED -> **overdue**, surface it.
                      + date within the horizon (today through today+7) -> upcoming, surface it.
                      + recurring stamps (`++2w`, `+1w`) -> compute the next occurrence.
                    - Under an `[#A]`/`[#B]` project umbrella, list the unchecked `[ ]`
                      next-actions and skip the `[X]` done ones.
                    - One-line project descriptions and stakeholder names for context.

                    **This file contains live production credentials, IPs, and passwords** for
                    core banking system integrations (SymXchange, jXChange, etc.). Never quote,
                    copy, or include any credential/IP/password into the output or into memory —
                    take only project names, statuses, dates, and plain descriptions.

                    **Email (Outlook, via m365-attachment-reader-local)** — actionable mail.
                    Launch a background general-purpose agent (tool details in the
                    `search-emails` skill) so it runs while you work Gitea + ServiceDesk + org. Give it
                    today's date, say the task is forward-looking, and ask it to return only
                    items needing David's action:
                    - flagged messages still open,
                    - threads where a reply from David is outstanding,
                    - vendor replies that unblock or block his work,
                    - meetings inside the horizon that need prep,
                    - deadlines named in mail.
                    Have it search active-project threads (Velera / disputes, BND Roughrider
                    Coin / Symitar / SymXchange, infinione / OFAC / Paylynx / SimpliRisk, plus
                    any project names surfaced from Gitea or the org file). It must separate
                    "action on David" from "waiting on vendor" and skip routine noise
                    (automated alerts, newsletters, no-prep invites).
                    If the connector is not authenticated, the agent will report a device-code
                    URL and code — surface those to David, deliver the list from Gitea + org +
                    ServiceDesk in the meantime, and offer to re-run the mail search once he
                    signs in.

                    ## 2. Merge sources — none is subordinate to another

                    - Items from two or more sources describing the same initiative become one
                      entry; let each source fill what the others lack (org file = deadline and
                      business context, Gitea = what is actually built, email = vendor and
                      stakeholder state, ServiceDesk = ticket status and requester work).
                    - An item present in only one source still counts — most real tasks show up
                      exactly once.
                    - On a status conflict, trust the most recent / most specific signal and say
                      so rather than silently picking one.
                    - Keep "needs David's action" strictly apart from "waiting on someone else".

                    ## 3. Deliver — terminal markdown, not an Artifact

                    This is a personal working list; keep it in the reply (do not publish an
                    Artifact). Structure:
                    - **Today — hard deadlines**: `DEADLINE` today or overdue, plus explicit
                      go-live / commitment dates from mail, plus ServiceDesk tickets due today
                      or overdue. Table each row with its source reference (`capcu.org:<line>`,
                      repo `#<n>`, `SDP #<id>`).
                    - **This week**: `[#A]`/`[#B]` work and project next-actions due within the
                      horizon.
                    - **Tomorrow (prep today)**: `SCHEDULED` items in the next day or two.
                    - **Waiting on others (track only)**: no action unless stalled.
                    - **Idle branches / lower priority**: stale PRs, `[#C]`/`[#D]` items.
                    - **Suggested order today**: a short ordered list — hard deadline first,
                      then highest business weight (A-priority, vendor-blocking,
                      launch-critical), then quick vendor unblocks, then the rest.
                    Flag scheduling collisions (two calendar items overlapping) explicitly.
                    Order within each section by priority cookie, then deadline proximity.

                    ## 4. After delivering

                    The list is disposable — do not save it to memory. Do refresh
                    time-sensitive memory snapshots if something material changed (a new project
                    umbrella, a new stakeholder, a shifted go-live date), marked with today's
                    date. Re-running after David edits the org file or authenticates the mail
                    connector is expected and cheap.
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
              - If something you're trying needs multiple dependencies, first try to get them all in a nix shell environment, and if this is not a one-off, or this requires NixOS configuration changes, recommend to the user to update their NixOS configuration to support what you are trying to do, then attempt a different method.

              ## Python

              - Target the project's configured Python version and dependency tooling.
              - Use the functional paradigm, dataclasses, pure functions, minimize mutable state and shadowing variables, etc. but no unnecessary functions that just pass their parameters to another function.
              - Use as many modern python type hints as possible
              - Keep functions focused and handle expected errors explicitly.

              ## Commands

              - when you try a command and the program is not available, then try again using `nix shell` to get the desired program before trying something else.
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
                      model = "openai/gpt-6-sol#high";
                      explore = "openai-explore";
                      general = "openai-general";
                      description = "The default agent. Executes tools based on configured permissions.";
                    };
                    "openai-plan" = mkPlan {
                      model = "openai/gpt-6-sol#high";
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
