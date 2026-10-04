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
