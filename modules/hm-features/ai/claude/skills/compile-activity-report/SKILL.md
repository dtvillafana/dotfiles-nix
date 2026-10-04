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
  `@gitea_llm_token@` into `GITEA_TOKEN` for
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
