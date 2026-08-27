{ ... }:
{
  flake.homeModules.ai =
    {
      config,
      lib,
      osConfig,
      ...
    }:
    {
      options.opencode.settings = lib.mkOption {
        type = lib.types.attrs;
        default = { };
        description = "Additional OpenCode configuration settings.";
      };

      config =
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
            home.file.".claude/skills/compile-activity-report/SKILL.md" =
              lib.mkIf (config.home.username == "capcu")
                {
                  text = ''
                    ---
                    name: compile-activity-report
                    description: Compile a report of David's completed/in-progress work over a date range, pulled from Gitea PR history, Outlook email, and his capcu.org work notes. Use when asked for an activity summary, status report, or "what have I done since X" to give to a supervisor or management.
                    ---

                    # Compile activity report

                    Produces a report of work completed (and, where relevant, in progress) over a
                    requested date range, for david.villafana@capcu.org. Default range if none is
                    given: since the 1st of the current month.

                    ## 1. Gather sources

                    Run these in parallel — they're independent.

                    **Gitea (ccugitea.capcu.org)** — one of three co-equal sources; covers
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

                    **Work notes** — `~/git-repos/orgfiles/work/capcu/capcu.org` — a third
                    co-equal source, not just enrichment text. Some completed or in-progress work
                    (vendor/account setup, planning, non-code tasks) is tracked only here and
                    must show up as its own initiative even with nothing to merge it into. An
                    Emacs org-mode file using `#+TODO: TODO MEET CALL WAITING EVENT | DONE
                    CANCELED DELEGATED`. Read it directly (it's a local file, not an API) and
                    look for:
                    - Headings/items whose state changed to `DONE` within the report window, or
                      whose surrounding notes/timestamps place them in that window — report
                      these as completed initiatives in their own right if they don't map to a
                      Gitea/email item.
                    - `WAITING`/`DELEGATED` items relevant to initiatives also seen in Gitea or
                      email — useful for the "in progress" section, and worth including on their
                      own even without a Gitea/email counterpart.
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

                    Gitea, email, and the org file are three co-equal sources of truth. Merge
                    them into one initiative list rather than treating any one as a footnote on
                    another:

                    - Where items from two or three sources clearly map to the same initiative,
                      merge into one entry and let each source fill in what the others lack
                      (email/org file give business context and vendor/task status; Gitea gives
                      what was actually built).
                    - Where an item from any single source has **no corresponding activity in
                      the others** (e.g. a vendor-coordination milestone from email, a non-code
                      task from the org file, a repo with no email or org-file trace), include
                      it as its own initiative — do not drop it just because it isn't
                      corroborated elsewhere. Most real work will only show up in one source.
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
                    - Include a stat row (3–4 numbers) sized to the audience: raw PR/repo counts
                      for a technical reader, outcome-shaped counts (e.g. "processes automated",
                      "initiatives in progress") for a management reader.
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
            home.file.".config/opencode/opencode.json".text = builtins.toJSON (
              lib.recursiveUpdate {
                "$schema" = "https://opencode.ai/config.json";
                plugin = [
                  "opencode-terminal-bell-notifier@0.2.0"
                  # "oh-my-openagent@4.19.4"
                ];
                agent = {
                  explore = {
                    model = "openai/gpt-5.6-luna";
                    mode = "subagent";
                  };
                  general = {
                    model = "openai/gpt-5.6-luna";
                    mode = "subagent";
                  };
                };
              } config.opencode.settings
            );
            home.file.".omo/omo.jsonc".text = builtins.toJSON {
              "[opencode]" = {
                "$schema" =
                  "https://raw.githubusercontent.com/code-yeongyu/oh-my-openagent/dev/assets/omo.schema.json";
                agents = {
                  sisyphus = {
                    model = "openai/gpt-5.6-sol";
                    reasoning = "medium";
                  };
                  hephaestus = {
                    model = "openai/gpt-5.6-sol";
                    reasoning = "medium";
                  };
                  oracle = {
                    model = "openai/gpt-5.6-sol";
                    reasoning = "xhigh";
                  };
                  librarian = {
                    model = "openai/gpt-5.6-luna";
                    reasoning = "low";
                  };
                  explore = {
                    model = "openai/gpt-5.6-luna";
                    reasoning = "low";
                  };
                  multimodal-looker = {
                    model = "openai/gpt-5.6-sol";
                    reasoning = "low";
                  };
                  prometheus.model = "openai/gpt-5.6-luna-fast";
                  metis.model = "openai/gpt-5.6-luna-fast";
                  momus = {
                    model = "openai/gpt-5.6-terra";
                    reasoning = "high";
                  };
                  atlas = {
                    model = "openai/gpt-5.6-sol";
                    reasoning = "medium";
                  };
                  sisyphus-junior = {
                    model = "openai/gpt-5.6-sol";
                    reasoning = "medium";
                  };
                };
                categories = {
                  visual-engineering = {
                    model = "openai/gpt-5.6-sol";
                    reasoning = "high";
                  };
                  ultrabrain = {
                    model = "openai/gpt-5.6-sol";
                    reasoning = "xhigh";
                  };
                  deep = {
                    model = "openai/gpt-5.6-sol";
                    reasoning = "medium";
                  };
                  artistry = {
                    model = "openai/gpt-5.6-sol";
                    reasoning = "xhigh";
                  };
                  quick.model = "openai/gpt-5.6-luna-fast";
                  unspecified-low = {
                    model = "openai/gpt-5.6-terra";
                    reasoning = "high";
                  };
                  unspecified-high = {
                    model = "openai/gpt-5.6-terra";
                    reasoning = "high";
                  };
                  writing = {
                    model = "openai/gpt-5.6-sol";
                    reasoning = "medium";
                  };
                };
              };
            };
            home.file.".omo/omo.jsonc".enable = false;
            home.activation.installOmoConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
              config="$HOME/.omo/omo.jsonc"
              mkdir -p "$HOME/.omo"
              if [ -L "$config" ]; then
                rm "$config"
              fi
              install -m 0644 "${config.home.file.".omo/omo.jsonc".source}" "$config"
            '';
          };
    };
}
