---
name: daily-tasks
description: Assemble David's prioritized list of what to work on today (or a stated day/week), merging open Gitea PRs and issues, ServiceDesk tickets, failed AWX jobs, capcu.org work-note deadlines, and actionable email. Use for "what should I work on today", "my tasks for today", "what's on my plate", or standup prep.
---

# Daily task list

Assembles a prioritized "what to work on now" list for
david.villafana@capcu.org. This is the forward-looking mirror of
`compile-activity-report` (which looks backward at finished work). Default
horizon: **today**. The user may widen it ("this week", "next few days").

## 1. Gather sources — in parallel, they are independent

**Do not start compiling the report (sections 2–3) until every search below
has finished** — Gitea, ServiceDesk, work notes, AWX, and the background email
agent. Wait for the email agent's completion notification before merging; do
not deliver a partial list and add mail "later". The only exception is a
source that is unavailable (MCP missing, connector unauthenticated): name it
in the report as not searched and why, then continue.

**Gitea (ccugitea.capcu.org)** — open code work.
- Read the API token from
  `@gitea_llm_token@` into `GITEA_TOKEN` for
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

**AWX (https://ccuawx.capcu.org)** — failed automation jobs.
- Read the token from `/run/secrets/awx_api_token` per command and send it as
  `Authorization: Bearer`; never echo it.
- List jobs finished in the last ~3 days:
  `GET /api/v2/jobs/?finished__gt=<ISO date>&order_by=-finished&page_size=200`
  (follow `next` if present). Group by `unified_job_template` / `name`.
- Report a template as **needs action** when its most recent finished run
  failed or errored (a later successful run clears an earlier failure; still
  mention repeated scheduled failures that were only cleared by a manual
  run, since the next schedule may fail again).
- For each needs-action template record: name, template id, last failure
  time, launch type, consecutive failure count, and the job ids. If it is
  cheap, read the failed job's `/api/v2/jobs/<id>/stdout/?format=txt` tail for
  a one-line cause; never quote credentials or member data from output.
- Cross-reference with email (e.g. a failed CoreIQ job and a "Core IQ Import
  Failure" mail are one entry).

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

**Cross-check ticket mentions in email against ServiceDesk** — do this in
the main session after the email agent reports (the agent may not have the
servicedesk MCP). Mail often forwards ticket notices ("RE-63604", "TMS 63436",
"SDP #63285", "Request Id ##RE-63436##"). The number is the ServiceDesk
request id. For every ticket id the email report mentions as an action
for David:
- Call `servicedesk_get_request` (or `servicedesk_get_request_summary`) and
  read `technician` and `status`.
- Assigned to David (`david.villafana@capcu.org`) -> keep it as action on
  him, merged with his assigned-queue row if it is already there.
- Unassigned (`technician` null) -> keep it only if the mail is addressed to
  him or the work clearly falls to him; note it as unassigned.
- Assigned to someone else (e.g. Jeremy) -> do not add it to his task list.
  At most mention it in one line under "Waiting on others" or the footnote
  ("assigned to <name>"), and only if it still affects his work.
- Closed/resolved -> drop it.
- A ticket the email report names but the assigned-queue list lacks is not
  David's by default; the lookup decides, not the email wording. If the MCP
  fails, say the ticket was not verified rather than assuming it is his.
Look tickets up by id only; never quote member PII from the ticket text.

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
Artifact).

**Format: tables with footnote references.** Every section is a markdown
table; do not use prose bullets for items. Keep each row terse (one short
phrase per cell) and move detail into numbered footnotes. Columns:
`# | Item | Source | Due / status | Next action | Ref` where Ref is a
footnote marker like `[1]`. Put all footnotes in a **Footnotes** section at
the end, numbered continuously across the whole report (`[1]`, `[2]`, …).
A footnote holds the extra data: the ticket/PR/org line details, notes from
mail (sender, date, what was asked), AWX job ids and failure cause, related
items merged into the row, and status conflicts. Never put credentials, IPs,
or member PII in a footnote.

Sections (omit empty ones):
- **Today — hard deadlines**: `DEADLINE` today or overdue, plus explicit
  go-live / commitment dates from mail, plus ServiceDesk tickets due today
  or overdue. Source column uses `capcu.org:<line>`, repo `#<n>`,
  `SDP #<id>`, `AWX #<template id>`, or `mail`.
- **Failed AWX jobs**: templates whose latest run failed (see AWX source),
  one row each, with cause and job ids in the footnote.
- **This week**: `[#A]`/`[#B]` work and project next-actions due within the
  horizon.
- **Tomorrow (prep today)**: `SCHEDULED` items in the next day or two.
- **Waiting on others (track only)**: no action unless stalled.
- **Idle branches / lower priority**: stale PRs, `[#C]`/`[#D]` items.
- **Suggested order today**: a short numbered list (the one non-table
  section) — hard deadline first, then highest business weight (A-priority,
  vendor-blocking, launch-critical), then quick vendor unblocks, then the
  rest.
- **Sources not searched**: only if a source was unavailable.
Flag scheduling collisions (two calendar items overlapping) explicitly.
Order within each section by priority cookie, then deadline proximity.

## 4. After delivering

The list is disposable — do not save it to memory. Do refresh
time-sensitive memory snapshots if something material changed (a new project
umbrella, a new stakeholder, a shifted go-live date), marked with today's
date. Re-running after David edits the org file or authenticates the mail
connector is expected and cheap.
