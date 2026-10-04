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
  subject/body/recipients or add attachments, `send_outlook_draft` to send
  it as saved, and `delete_outlook_draft` to discard. Edit, send, and delete
  refuse sent mail. Confirm before delete.
- When the user approves sending a draft you already saved, call
  `send_outlook_draft` with its `draftId`. Do not resend the text with
  `send_now: true`; that leaves a duplicate draft behind.

If every To/Cc/Bcc address ends in `@capcu.org`, end the body with a small
footer that says exactly: Sent by Claude. Omit that footer when any
recipient is outside `@capcu.org`.
