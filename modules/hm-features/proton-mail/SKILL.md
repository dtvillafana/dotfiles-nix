---
name: Proton Mail
description: Search, read, draft, edit, delete, and send Proton Mail through the protonmail_bridge MCP. Load before any Proton Mail task.
---

Use the `protonmail_bridge` tools. UIDs belong to one folder. A Sent UID is not an INBOX or Drafts UID.

## Find

1. `search_emails` with the narrowest criteria: folder, sender, subject, since (`YYYY-MM-DD`). It returns the newest matches, up to `limit`.
2. Prefer `INBOX` for new mail, `Sent` for mail we sent, and `Drafts` for drafts. Use `All Mail` only when the folder is unknown. Do not search `INBOX` and `All Mail` for the same thread.
3. `get_email` only for the UID you will quote or answer. Do not fetch every hit.
4. `download_attachments` only when a file is needed. Pass `filename_contains` when the name is known. Downloads stay inside the current project (or `NDRL_BOARD_ROOT` when explicitly set).

Independent searches may run together. Do not read, edit, or send until the search that produced the UID has returned.

## Draft

- New message or reply: `save_draft`. Pass `reply_uid` to fill In-Reply-To, References, `Re:` subject, and To. Do not retype those headers.
- `save_draft` always creates another message. Never call it to update an existing draft.
- List drafts with `search_emails(folder="Drafts")`, then `read_draft` for the one UID you need.
- `read_draft` may truncate. If `truncated` is true and the missing text matters, call it again with a higher `max_chars`. Do not paste a truncated body into `edit_draft`.
- Change a draft with `edit_draft` and only the fields that change. Omitted fields stay as stored. `[]` clears a recipient list. `""` clears subject, body, or reply headers.
- `edit_draft` appends a replacement and deletes the old UID. Use the returned `uid` after that. Do not keep using the old one.
- If you replace the body of an HTML draft with plain text, pass `html=false`.
- Discard with `delete_draft(uid, confirm=true)` only after the user asks to discard that draft. Read it first if the subject is not already known. Do not delete before a requested send has succeeded.

## Send

Show the user the exact To, Cc, Bcc, subject, and body. Call `send_email` with `confirm=true` only after they approve that exact text.

`send_email` does not delete the draft. After a successful send, call `delete_draft` only if the user asked to discard it. From is always the Bridge account.

Do not send, edit, and delete the same draft in parallel.
