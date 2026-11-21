#!/usr/bin/env python3
"""MCP server: Proton Mail via official Bridge IMAP and SMTP."""

from __future__ import annotations

import getpass
import imaplib
import os
import re
import smtplib
import ssl
import sys
from contextlib import contextmanager
from dataclasses import dataclass
from datetime import datetime
from email import message_from_bytes
from email.header import decode_header, make_header
from email.message import EmailMessage, Message
from email.utils import formatdate, getaddresses, make_msgid, parsedate_to_datetime
from pathlib import Path
from typing import Iterator

from mcp.server.fastmcp import FastMCP
from mcp.server.fastmcp.exceptions import ToolError


IMAP_HOST = "127.0.0.1"
IMAP_PORT = 1143
SMTP_HOST = "127.0.0.1"
SMTP_PORT = 1025
DRAFTS_FOLDER = "Drafts"
DEFAULT_DEST = "email-attachments"
CREDENTIAL_KEYS = ("bridge_username", "bridge_password")
MAX_RECIPIENTS = 50
MAX_BODY_CHARS = 100_000
SEND_CONFIRM_ERROR = (
    "Refusing to send. Pass confirm=true only after the user has approved "
    "the exact recipients, subject, and body."
)
DELETE_DRAFT_CONFIRM_ERROR = (
    "Refusing to delete. Pass confirm=true only after the user has asked "
    "to discard this draft."
)

mcp = FastMCP("protonmail-bridge")


@dataclass(frozen=True)
class ImapConfig:
    username: str
    password: str
    host: str = IMAP_HOST
    port: int = IMAP_PORT


@dataclass
class EmailHit:
    uid: str
    folder: str
    date: str
    sender: str
    subject: str
    attachments: list[str]
    body_preview: str | None = None


@dataclass
class SearchResult:
    criteria: str
    folder: str
    count: int
    messages: list[EmailHit]


@dataclass
class EmailBody:
    uid: str
    folder: str
    date: str
    sender: str
    subject: str
    attachments: list[str]
    body: str


@dataclass
class SavedAttachment:
    uid: str
    filename: str
    path: str
    size: int


@dataclass
class DownloadResult:
    saved: list[SavedAttachment]
    skipped: list[str]


@dataclass
class DraftResult:
    folder: str
    uid: str | None
    message_id: str
    subject: str
    to: list[str]
    cc: list[str]
    bcc: list[str]
    replaced_uid: str | None = None


@dataclass
class DraftBody:
    uid: str
    folder: str
    date: str
    message_id: str
    in_reply_to: str | None
    references: str | None
    subject: str
    to: list[str]
    cc: list[str]
    bcc: list[str]
    html: bool
    attachments: list[str]
    body: str
    truncated: bool


@dataclass(frozen=True)
class DraftSource:
    message_id: str
    subject: str
    body: str
    to: tuple[str, ...]
    cc: tuple[str, ...]
    bcc: tuple[str, ...]
    html: bool
    in_reply_to: str | None
    references: str | None


@dataclass
class DeletedDraft:
    folder: str
    uid: str
    subject: str


@dataclass
class SendResult:
    message_id: str
    subject: str
    to: list[str]
    cc: list[str]
    bcc: list[str]


@dataclass(frozen=True)
class ReplyContext:
    subject: str
    in_reply_to: str | None
    references: str | None
    to: tuple[str, ...]


def credential_file_paths() -> list[Path]:
    paths: list[Path] = []
    root = os.environ.get("NDRL_BOARD_ROOT")
    if root:
        paths.append(Path(root) / ".bridge.env")
    xdg = Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config"))
    paths.append(xdg / "ndrl-board" / "bridge.env")
    return paths


def parse_env_file(path: Path) -> dict[str, str]:
    if not path.is_file():
        return {}
    values: dict[str, str] = {}
    for raw in path.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, _, value = line.partition("=")
        key = key.strip()
        value = value.strip()
        if len(value) >= 2 and value[0] == value[-1] and value[0] in {"'", '"'}:
            value = value[1:-1]
        if key:
            values[key] = value
    return values


def apply_saved_credentials() -> None:
    for key in CREDENTIAL_KEYS:
        if os.environ.get(key, "").strip():
            continue
        for path in credential_file_paths():
            saved = parse_env_file(path).get(key, "").strip()
            if saved:
                os.environ[key] = saved
                break


def write_credentials(username: str, password: str) -> Path:
    dest = credential_file_paths()[-1]
    dest.parent.mkdir(parents=True, exist_ok=True)
    dest.write_text(
        f"bridge_username={username}\nbridge_password={password}\n",
        encoding="utf-8",
    )
    dest.chmod(0o600)
    return dest


def require_config() -> ImapConfig:
    apply_saved_credentials()
    username = os.environ.get("bridge_username", "").strip()
    password = os.environ.get("bridge_password", "").strip()
    if not username or not password:
        raise ToolError(
            "Missing Bridge IMAP login. Run "
            "`protonmail-bridge-mcp --configure` (Proton address and the password from "
            "`protonmail-bridge --cli` then `info`)."
        )
    return ImapConfig(username=username, password=password)


def configure_main() -> None:
    apply_saved_credentials()
    username = os.environ.get("bridge_username", "").strip()
    password = os.environ.get("bridge_password", "").strip()
    if not username:
        username = input("Proton address (bridge_username): ").strip()
    if not password:
        password = getpass.getpass(
            "Bridge IMAP password (protonmail-bridge --cli, then info): "
        ).strip()
    if not username or not password:
        raise SystemExit("bridge_username and bridge_password are required.")
    dest = write_credentials(username, password)
    os.environ["bridge_username"] = username
    os.environ["bridge_password"] = password
    try:
        mail = connect(require_config())
        mail.logout()
    except ToolError as exc:
        raise SystemExit(str(exc)) from exc
    print(f"Wrote {dest} (mode 600)")
    print("IMAP login ok. OpenCode MCP command is protonmail-bridge-mcp.")


def decode_mime_header(value: str | None) -> str:
    if not value:
        return ""
    return str(make_header(decode_header(value)))


def quote_mailbox(folder: str) -> str:
    if folder.startswith('"') and folder.endswith('"'):
        return folder
    return f'"{folder}"'


def tls_context() -> ssl.SSLContext:
    ctx = ssl.create_default_context()
    ctx.check_hostname = False
    ctx.verify_mode = ssl.CERT_NONE
    return ctx


def connect(config: ImapConfig) -> imaplib.IMAP4:
    try:
        mail = imaplib.IMAP4(host=config.host, port=config.port)
    except OSError as exc:
        raise ToolError(
            f"Could not connect to Proton Mail Bridge IMAP at {config.host}:{config.port}. "
            "Start it with `protonmail-bridge --noninteractive`. "
            f"({exc})"
        ) from exc
    try:
        mail.starttls(ssl_context=tls_context())
    except imaplib.IMAP4.error as exc:
        raise ToolError(
            "STARTTLS failed. Official Proton Mail Bridge requires STARTTLS on 1143."
        ) from exc
    status, _ = mail.login(config.username, config.password)
    if status != "OK":
        raise ToolError(
            "IMAP login failed. Use your Proton address and the Bridge password from `info`."
        )
    return mail


@contextmanager
def imap_session() -> Iterator[imaplib.IMAP4]:
    mail = connect(require_config())
    try:
        yield mail
    finally:
        try:
            mail.logout()
        except Exception:
            pass


def select_folder(mail: imaplib.IMAP4, folder: str) -> None:
    status, _ = mail.select(quote_mailbox(folder))
    if status != "OK":
        raise ToolError(f"Could not select folder {folder!r}.")


def list_mailbox_names(mail: imaplib.IMAP4) -> list[str]:
    status, data = mail.list()
    if status != "OK" or data is None:
        raise ToolError("Could not list IMAP folders.")
    folders: list[str] = []
    for raw in data:
        if raw is None:
            continue
        line = raw.decode() if isinstance(raw, bytes) else str(raw)
        if ' "/" ' in line:
            name = line.split(' "/" ', 1)[1].strip()
        elif ' "." ' in line:
            name = line.split(' "." ', 1)[1].strip()
        else:
            name = line.rsplit(" ", 1)[-1]
        folders.append(name.strip('"'))
    return folders


def quote_search_value(value: str) -> str:
    if any(char in value for char in "\r\n\x00"):
        raise ToolError("Search values must not contain CR, LF, or NUL characters")
    escaped = value.replace("\\", "\\\\").replace('"', '\\"')
    return f'"{escaped}"'


def build_criteria(
    *,
    sender: str | None,
    subject: str | None,
    since: datetime | None,
    text: str | None,
) -> str:
    parts: list[str] = []
    if sender:
        parts.append(f"FROM {quote_search_value(sender)}")
    if subject:
        parts.append(f"SUBJECT {quote_search_value(subject)}")
    if since is not None:
        parts.append(f'SENTSINCE "{since.strftime("%d-%b-%Y")}"')
    if text:
        parts.append(f"TEXT {quote_search_value(text)}")
    if not parts:
        return "ALL"
    return f"({' '.join(parts)})"


def parse_since(value: str) -> datetime:
    try:
        return datetime.strptime(value, "%Y-%m-%d")
    except ValueError as exc:
        raise ToolError("since must be YYYY-MM-DD") from exc


def message_datetime(msg: Message) -> datetime | None:
    value = msg.get("Date")
    if not value:
        return None
    parsed = parsedate_to_datetime(value)
    if parsed.tzinfo is not None:
        return parsed.astimezone().replace(tzinfo=None)
    return parsed


def iter_attachments(msg: Message) -> list[tuple[str, bytes]]:
    attachments: list[tuple[str, bytes]] = []
    for part in msg.walk():
        filename = part.get_filename()
        if not filename:
            continue
        payload = part.get_payload(decode=True)
        if not isinstance(payload, bytes):
            continue
        attachments.append((decode_mime_header(filename), payload))
    return attachments


def payload_text(part: Message) -> str:
    payload = part.get_payload(decode=True)
    if isinstance(payload, bytes):
        charset = part.get_content_charset() or "utf-8"
        return payload.decode(charset, errors="replace")
    if isinstance(payload, str):
        return payload
    return ""


def extract_body(msg: Message) -> str:
    if msg.is_multipart():
        for part in msg.walk():
            if part.get_content_type() == "text/plain" and not part.get_filename():
                text = payload_text(part)
                if text.strip():
                    return text
        for part in msg.walk():
            if part.get_content_type() == "text/html" and not part.get_filename():
                text = payload_text(part)
                if text.strip():
                    return text
        return ""
    return payload_text(msg)


def fetch_uid(mail: imaplib.IMAP4, uid: str) -> Message:
    status, msg_data = mail.uid("FETCH", uid, "(RFC822)")
    if status != "OK" or not msg_data:
        raise ToolError(f"Could not fetch UID {uid}.")
    for raw in msg_data:
        if isinstance(raw, tuple) and isinstance(raw[1], bytes):
            return message_from_bytes(raw[1])
    raise ToolError(f"Could not fetch UID {uid}.")


def to_hit(msg: Message, uid: str, folder: str, include_preview: bool) -> EmailHit:
    when = message_datetime(msg)
    preview = extract_body(msg)[:500] if include_preview else None
    return EmailHit(
        uid=uid,
        folder=folder,
        date=when.strftime("%Y-%m-%d %H:%M") if when else "",
        sender=decode_mime_header(msg.get("From")),
        subject=decode_mime_header(msg.get("Subject")),
        attachments=[name for name, _ in iter_attachments(msg)],
        body_preview=preview,
    )


def repo_root() -> Path:
    return Path(os.environ.get("NDRL_BOARD_ROOT", os.getcwd())).resolve()


def resolve_dest(dest_dir: str) -> Path:
    root = repo_root()
    dest = Path(dest_dir).expanduser()
    dest = dest if dest.is_absolute() else (root / dest)
    dest = dest.resolve()
    try:
        dest.relative_to(root)
    except ValueError as exc:
        raise ToolError(f"dest_dir must stay inside {root}") from exc
    dest.mkdir(parents=True, exist_ok=True)
    return dest


def safe_filename(name: str) -> str:
    base = Path(name).name
    cleaned = re.sub(r"[^A-Za-z0-9 ._+\-()[\]]+", "_", base).strip(" .")
    return cleaned or "attachment"


@mcp.tool()
def list_folders() -> list[str]:
    """List IMAP folders on official Proton Mail Bridge (127.0.0.1:1143 STARTTLS)."""
    with imap_session() as mail:
        return list_mailbox_names(mail)


@mcp.tool()
def search_emails(
    folder: str = "INBOX",
    sender: str | None = None,
    subject: str | None = None,
    text: str | None = None,
    since: str | None = None,
    limit: int = 25,
    include_body_preview: bool = False,
) -> SearchResult:
    """Search Proton Mail through official Bridge IMAP.

    Use YYYY-MM-DD for since. Returns UIDs, headers, and attachment names.
    protonmail-bridge must already be running on 127.0.0.1:1143.
    """
    if limit < 1 or limit > 100:
        raise ToolError("limit must be between 1 and 100")
    since_dt = parse_since(since) if since else None
    criteria = build_criteria(sender=sender, subject=subject, since=since_dt, text=text)
    with imap_session() as mail:
        select_folder(mail, folder)
        status, data = mail.uid("SEARCH", None, criteria)
        if status != "OK" or not data or not data[0]:
            return SearchResult(criteria=criteria, folder=folder, count=0, messages=[])
        uids = data[0].split()
        selected = uids[-limit:]
        messages = [
            to_hit(
                fetch_uid(mail, uid.decode()),
                uid.decode(),
                folder,
                include_body_preview,
            )
            for uid in selected
        ]
    return SearchResult(
        criteria=criteria, folder=folder, count=len(messages), messages=messages
    )


@mcp.tool()
def get_email(uid: str, folder: str = "INBOX", max_chars: int = 4000) -> EmailBody:
    """Fetch one message by IMAP UID, including body text and attachment names."""
    if max_chars < 1 or max_chars > 20000:
        raise ToolError("max_chars must be between 1 and 20000")
    with imap_session() as mail:
        select_folder(mail, folder)
        msg = fetch_uid(mail, uid)
    when = message_datetime(msg)
    body = extract_body(msg)
    if len(body) > max_chars:
        body = body[:max_chars] + "\n…[truncated]"
    return EmailBody(
        uid=uid,
        folder=folder,
        date=when.strftime("%Y-%m-%d %H:%M") if when else "",
        sender=decode_mime_header(msg.get("From")),
        subject=decode_mime_header(msg.get("Subject")),
        attachments=[name for name, _ in iter_attachments(msg)],
        body=body,
    )


@mcp.tool()
def download_attachments(
    uids: list[str],
    folder: str = "INBOX",
    dest_dir: str = DEFAULT_DEST,
    filename_contains: str | None = None,
) -> DownloadResult:
    """Download attachments for the given IMAP UIDs into dest_dir under this repo.

    dest_dir is relative to the current project root unless absolute and still inside it.
    Optional filename_contains filters attachment names (case-insensitive).
    """
    if not uids:
        raise ToolError("uids must not be empty")
    dest = resolve_dest(dest_dir)
    needle = filename_contains.lower() if filename_contains else None
    saved: list[SavedAttachment] = []
    skipped: list[str] = []
    with imap_session() as mail:
        select_folder(mail, folder)
        for uid in uids:
            msg = fetch_uid(mail, uid)
            attachments = iter_attachments(msg)
            if not attachments:
                skipped.append(f"{uid}: no attachments")
                continue
            for name, payload in attachments:
                if needle and needle not in name.lower():
                    skipped.append(f"{uid}: skipped {name}")
                    continue
                target = dest / f"{uid}-{safe_filename(name)}"
                target.write_bytes(payload)
                saved.append(
                    SavedAttachment(
                        uid=uid,
                        filename=name,
                        path=str(target),
                        size=len(payload),
                    )
                )
    return DownloadResult(saved=saved, skipped=skipped)


def reject_header_value(value: str, field: str) -> str:
    if any(char in value for char in "\r\n\x00"):
        raise ToolError(f"{field} must not contain CR, LF, or NUL")
    return value


def addr_spec(value: str) -> str:
    match = re.search(r"<([^<>]+)>", value)
    return (match.group(1) if match else value).strip()


def parse_address(value: str, field: str) -> str:
    cleaned = reject_header_value(value, field).strip()
    if not cleaned:
        raise ToolError(f"{field} address must not be empty")
    pairs = getaddresses([cleaned])
    if len(pairs) != 1 or not pairs[0][1] or pairs[0][1].count("@") != 1:
        raise ToolError(f"Invalid {field} address")
    name, addr = pairs[0]
    local, _, domain = addr.partition("@")
    if (
        not local
        or any(char in addr for char in " \t<>")
        or "." not in domain
        or domain.startswith(".")
        or domain.endswith(".")
    ):
        raise ToolError(f"Invalid {field} address")
    return f"{name} <{addr}>" if name else addr


def clean_addresses(values: list[str] | None, field: str) -> tuple[str, ...]:
    if not values:
        return ()
    cleaned = tuple(parse_address(value, field) for value in values)
    if len(cleaned) > MAX_RECIPIENTS:
        raise ToolError(f"{field} has too many addresses (max {MAX_RECIPIENTS})")
    return cleaned


def clean_header(value: str, field: str, *, max_len: int = 998) -> str:
    cleaned = reject_header_value(value, field).strip()
    if len(cleaned) > max_len:
        raise ToolError(f"{field} is too long")
    return cleaned


def format_message_id(value: str, field: str = "in_reply_to") -> str:
    cleaned = clean_header(value, field).strip()
    inner = cleaned.strip("<>").strip()
    if not inner or any(char.isspace() for char in inner):
        raise ToolError(f"{field} must be a single message id")
    return f"<{inner}>"


def format_references(value: str) -> str:
    cleaned = clean_header(value, "references")
    if not cleaned:
        raise ToolError("references must not be empty")
    return " ".join(format_message_id(part, "references") for part in cleaned.split())


def reply_subject(subject: str) -> str:
    if subject.lower().startswith("re:"):
        return subject
    return f"Re: {subject}" if subject else "Re:"


def header_addresses(msg: Message, header: str) -> tuple[str, ...]:
    raw = decode_mime_header(msg.get(header))
    if not raw:
        return ()
    return tuple(
        f"{name} <{addr}>" if name else addr
        for name, addr in getaddresses([raw])
        if addr
    )


def reply_context(msg: Message, own_addr: str) -> ReplyContext:
    message_id = decode_mime_header(msg.get("Message-ID")).strip()
    prior_refs = decode_mime_header(msg.get("References")).strip()
    in_reply_to = format_message_id(message_id) if message_id else None
    references = None
    if in_reply_to:
        references = f"{prior_refs} {in_reply_to}".strip() if prior_refs else in_reply_to
    own = addr_spec(own_addr).lower()
    preferred = header_addresses(msg, "Reply-To") or header_addresses(msg, "From")
    recipients = tuple(addr for addr in preferred if addr_spec(addr).lower() != own)
    if not recipients:
        recipients = tuple(
            addr for addr in header_addresses(msg, "To") if addr_spec(addr).lower() != own
        )
    subject = reply_subject(decode_mime_header(msg.get("Subject")).strip())
    return ReplyContext(
        subject=subject,
        in_reply_to=in_reply_to,
        references=references,
        to=recipients,
    )


def compose_message(
    *,
    from_addr: str,
    to: tuple[str, ...] = (),
    cc: tuple[str, ...] = (),
    bcc: tuple[str, ...] = (),
    subject: str = "",
    body: str = "",
    html: bool = False,
    in_reply_to: str | None = None,
    references: str | None = None,
) -> EmailMessage:
    if len(body) > MAX_BODY_CHARS:
        raise ToolError(f"body is too long (max {MAX_BODY_CHARS} characters)")
    sender = parse_address(from_addr, "from")
    to = tuple(parse_address(addr, "to") for addr in to)
    cc = tuple(parse_address(addr, "cc") for addr in cc)
    bcc = tuple(parse_address(addr, "bcc") for addr in bcc)
    subject = clean_header(subject, "subject") if subject else ""
    if in_reply_to:
        in_reply_to = format_message_id(in_reply_to)
    if references:
        references = format_references(references)
    message = EmailMessage()
    message["From"] = sender
    if to:
        message["To"] = ", ".join(to)
    if cc:
        message["Cc"] = ", ".join(cc)
    if bcc:
        message["Bcc"] = ", ".join(bcc)
    message["Subject"] = subject
    message["Date"] = formatdate(localtime=True)
    domain = addr_spec(sender).rsplit("@", 1)[-1]
    message["Message-ID"] = make_msgid(domain=domain)
    if in_reply_to:
        message["In-Reply-To"] = in_reply_to
    if references:
        message["References"] = references
    if html:
        plain = re.sub(r"<[^>]+>", "", body)
        plain = re.sub(r"[ \t]+\n", "\n", plain).strip() or "(HTML message)"
        message.set_content(plain)
        message.add_alternative(body, subtype="html")
    else:
        message.set_content(body)
    return message


def envelope_recipients(message: EmailMessage) -> list[str]:
    raw = [
        message.get("To", ""),
        message.get("Cc", ""),
        message.get("Bcc", ""),
    ]
    return [addr for _, addr in getaddresses(raw) if addr]


def parse_append_uid(data: list[object] | None) -> str | None:
    parts: list[str] = []
    for item in data or []:
        if isinstance(item, bytes):
            parts.append(item.decode(errors="replace"))
        elif isinstance(item, tuple):
            parts.extend(
                part.decode(errors="replace") if isinstance(part, bytes) else str(part)
                for part in item
            )
        else:
            parts.append(str(item))
    match = re.search(r"APPENDUID \d+ (\d+)", " ".join(parts))
    return match.group(1) if match else None


def apply_reply(
    mail: imaplib.IMAP4,
    *,
    reply_uid: str,
    reply_folder: str,
    own_addr: str,
    subject: str,
    to: tuple[str, ...],
    cc: tuple[str, ...],
    bcc: tuple[str, ...],
    in_reply_to: str | None,
    references: str | None,
) -> tuple[str, tuple[str, ...], str | None, str | None]:
    select_folder(mail, reply_folder)
    context = reply_context(fetch_uid(mail, reply_uid), own_addr)
    if not subject and context.subject:
        subject = clean_header(context.subject, "subject")
    if in_reply_to is None:
        in_reply_to = context.in_reply_to
    if references is None:
        references = context.references
    if not to and not cc and not bcc:
        to = tuple(parse_address(addr, "to") for addr in context.to)
    return subject, to, in_reply_to, references


def prepare_outgoing(
    config: ImapConfig,
    *,
    mail: imaplib.IMAP4 | None,
    to: list[str] | None,
    cc: list[str] | None,
    bcc: list[str] | None,
    subject: str,
    body: str,
    html: bool,
    in_reply_to: str | None,
    references: str | None,
    reply_uid: str | None,
    reply_folder: str,
    require_recipient: bool,
    require_body: bool,
) -> EmailMessage:
    if require_body and not body.strip():
        raise ToolError("body is required to send")
    if not subject.strip() and not body.strip():
        raise ToolError("A subject or body is required")
    to_addrs = clean_addresses(to, "to")
    cc_addrs = clean_addresses(cc, "cc")
    bcc_addrs = clean_addresses(bcc, "bcc")
    subject_clean = clean_header(subject, "subject") if subject else ""
    reply_to = format_message_id(in_reply_to) if in_reply_to else None
    refs = format_references(references) if references else None
    if reply_uid:
        if mail is None:
            raise ToolError("reply_uid requires an IMAP session")
        subject_clean, to_addrs, reply_to, refs = apply_reply(
            mail,
            reply_uid=reply_uid,
            reply_folder=reply_folder,
            own_addr=config.username,
            subject=subject_clean,
            to=to_addrs,
            cc=cc_addrs,
            bcc=bcc_addrs,
            in_reply_to=reply_to,
            references=refs,
        )
    if require_recipient and not (to_addrs or cc_addrs or bcc_addrs):
        raise ToolError("At least one To, Cc, or Bcc address is required to send")
    return compose_message(
        from_addr=config.username,
        to=to_addrs,
        cc=cc_addrs,
        bcc=bcc_addrs,
        subject=subject_clean,
        body=body,
        html=html,
        in_reply_to=reply_to,
        references=refs,
    )


def connect_smtp(config: ImapConfig) -> smtplib.SMTP:
    try:
        client = smtplib.SMTP(host=SMTP_HOST, port=SMTP_PORT, timeout=30)
    except OSError as exc:
        raise ToolError(
            f"Could not connect to Proton Mail Bridge SMTP at {SMTP_HOST}:{SMTP_PORT}. "
            "Start it with `protonmail-bridge --noninteractive`. "
            f"({exc})"
        ) from exc
    try:
        client.starttls(context=tls_context())
        client.login(config.username, config.password)
    except smtplib.SMTPException as exc:
        try:
            client.quit()
        except smtplib.SMTPException:
            pass
        raise ToolError(
            "SMTP login failed. Use the same Proton address and Bridge password as IMAP."
        ) from exc
    return client


@contextmanager
def smtp_session(config: ImapConfig) -> Iterator[smtplib.SMTP]:
    client = connect_smtp(config)
    try:
        yield client
    finally:
        try:
            client.quit()
        except smtplib.SMTPException:
            pass


@mcp.tool()
def save_draft(
    subject: str = "",
    body: str = "",
    to: list[str] | None = None,
    cc: list[str] | None = None,
    bcc: list[str] | None = None,
    html: bool = False,
    in_reply_to: str | None = None,
    references: str | None = None,
    reply_uid: str | None = None,
    reply_folder: str = "INBOX",
) -> DraftResult:
    """Save a message in Drafts via IMAP APPEND. Does not send.

    Proton Mail Bridge syncs the Drafts folder to Proton. Pass reply_uid to
    fill In-Reply-To, References, Re: subject, and To when those are omitted.
    Bcc is stored on the draft and is not delivered. To change an existing
    draft, use edit_draft; save_draft always creates another message.
    """
    config = require_config()
    with imap_session() as mail:
        message = prepare_outgoing(
            config,
            mail=mail,
            to=to,
            cc=cc,
            bcc=bcc,
            subject=subject,
            body=body,
            html=html,
            in_reply_to=in_reply_to,
            references=references,
            reply_uid=reply_uid,
            reply_folder=reply_folder,
            require_recipient=False,
            require_body=False,
        )
        status, data = mail.append(DRAFTS_FOLDER, "\\Draft", None, message.as_bytes())
        if status != "OK":
            detail = data[0].decode(errors="replace") if data else status
            raise ToolError(f"Could not save draft: {detail}")
    return DraftResult(
        folder=DRAFTS_FOLDER,
        uid=parse_append_uid(list(data) if data else None),
        message_id=str(message["Message-ID"]),
        subject=message["Subject"] or "",
        to=list(header_addresses(message, "To")),
        cc=list(header_addresses(message, "Cc")),
        bcc=list(header_addresses(message, "Bcc")),
    )


def html_part_text(msg: Message) -> str:
    if msg.get_content_type() == "text/html" and not msg.get_filename():
        return payload_text(msg)
    if not msg.is_multipart():
        return ""
    for part in msg.walk():
        if part.get_content_type() == "text/html" and not part.get_filename():
            text = payload_text(part)
            if text.strip():
                return text
    return ""


def header_or_none(msg: Message, name: str) -> str | None:
    value = decode_mime_header(msg.get(name)).strip()
    return value or None


def draft_source(msg: Message) -> DraftSource:
    html_body = html_part_text(msg)
    html = bool(html_body.strip())
    body = html_body if html else extract_body(msg)
    return DraftSource(
        message_id=header_or_none(msg, "Message-ID") or "",
        subject=decode_mime_header(msg.get("Subject")).strip(),
        body=body,
        to=header_addresses(msg, "To"),
        cc=header_addresses(msg, "Cc"),
        bcc=header_addresses(msg, "Bcc"),
        html=html,
        in_reply_to=header_or_none(msg, "In-Reply-To"),
        references=header_or_none(msg, "References"),
    )


def apply_draft_edit(
    source: DraftSource,
    *,
    subject: str | None = None,
    body: str | None = None,
    to: list[str] | None = None,
    cc: list[str] | None = None,
    bcc: list[str] | None = None,
    html: bool | None = None,
    in_reply_to: str | None = None,
    references: str | None = None,
) -> DraftSource:
    return DraftSource(
        message_id=source.message_id,
        subject=source.subject if subject is None else subject,
        body=source.body if body is None else body,
        to=source.to if to is None else tuple(to),
        cc=source.cc if cc is None else tuple(cc),
        bcc=source.bcc if bcc is None else tuple(bcc),
        html=source.html if html is None else html,
        in_reply_to=source.in_reply_to if in_reply_to is None else (in_reply_to or None),
        references=source.references if references is None else (references or None),
    )


def clip_text(text: str, max_chars: int) -> tuple[str, bool]:
    if len(text) <= max_chars:
        return text, False
    return text[:max_chars] + "\n…[truncated]", True


def delete_draft_uid(mail: imaplib.IMAP4, uid: str) -> None:
    select_folder(mail, DRAFTS_FOLDER)
    status, _ = mail.uid("STORE", uid, "+FLAGS", "(\\Deleted)")
    if status != "OK":
        raise ToolError(f"Could not mark draft {uid} deleted")
    status, _ = mail.uid("EXPUNGE", uid)
    if status != "OK":
        status, _ = mail.expunge()
        if status != "OK":
            raise ToolError(f"Could not expunge draft {uid}")


def draft_result(message: EmailMessage, uid: str | None, replaced_uid: str | None = None) -> DraftResult:
    return DraftResult(
        folder=DRAFTS_FOLDER,
        uid=uid,
        message_id=str(message["Message-ID"]),
        subject=str(message["Subject"] or ""),
        to=list(header_addresses(message, "To")),
        cc=list(header_addresses(message, "Cc")),
        bcc=list(header_addresses(message, "Bcc")),
        replaced_uid=replaced_uid,
    )


@mcp.tool()
def read_draft(uid: str, max_chars: int = 4000) -> DraftBody:
    """Read one Drafts message by its Drafts-folder UID.

    The body is plain text when a plain part exists, even if html is true.
    Omitted edit_draft fields are taken from the stored message, so do not
    paste a truncated body back. Raise max_chars only when truncated is true
    and the missing text is needed.
    """
    if max_chars < 1 or max_chars > 20000:
        raise ToolError("max_chars must be between 1 and 20000")
    with imap_session() as mail:
        select_folder(mail, DRAFTS_FOLDER)
        msg = fetch_uid(mail, uid)
    source = draft_source(msg)
    display = extract_body(msg) or source.body
    body, truncated = clip_text(display, max_chars)
    when = message_datetime(msg)
    return DraftBody(
        uid=uid,
        folder=DRAFTS_FOLDER,
        date=when.strftime("%Y-%m-%d %H:%M") if when else "",
        message_id=source.message_id,
        in_reply_to=source.in_reply_to,
        references=source.references,
        subject=source.subject,
        to=list(source.to),
        cc=list(source.cc),
        bcc=list(source.bcc),
        html=source.html,
        attachments=[name for name, _ in iter_attachments(msg)],
        body=body,
        truncated=truncated,
    )


@mcp.tool()
def edit_draft(
    uid: str,
    subject: str | None = None,
    body: str | None = None,
    to: list[str] | None = None,
    cc: list[str] | None = None,
    bcc: list[str] | None = None,
    html: bool | None = None,
    in_reply_to: str | None = None,
    references: str | None = None,
) -> DraftResult:
    """Replace one Drafts message. Omitted fields stay as stored.

    Pass [] to clear To, Cc, or Bcc. Pass "" to clear subject, body, or reply
    headers. IMAP cannot edit in place: this appends a replacement, then
    deletes the old UID. Use the returned uid afterward. Does not send.
    """
    if all(
        value is None
        for value in (subject, body, to, cc, bcc, html, in_reply_to, references)
    ):
        raise ToolError("Pass at least one field to change")
    config = require_config()
    with imap_session() as mail:
        select_folder(mail, DRAFTS_FOLDER)
        source = draft_source(fetch_uid(mail, uid))
        edited = apply_draft_edit(
            source,
            subject=subject,
            body=body,
            to=to,
            cc=cc,
            bcc=bcc,
            html=html,
            in_reply_to=in_reply_to,
            references=references,
        )
        if edited == source:
            raise ToolError("No draft fields changed")
        message = compose_message(
            from_addr=config.username,
            to=edited.to,
            cc=edited.cc,
            bcc=edited.bcc,
            subject=edited.subject,
            body=edited.body,
            html=edited.html,
            in_reply_to=edited.in_reply_to,
            references=edited.references,
        )
        status, data = mail.append(DRAFTS_FOLDER, "\\Draft", None, message.as_bytes())
        if status != "OK":
            detail = data[0].decode(errors="replace") if data else status
            raise ToolError(f"Could not save replacement draft: {detail}")
        new_uid = parse_append_uid(list(data) if data else None)
        try:
            delete_draft_uid(mail, uid)
        except ToolError as exc:
            raise ToolError(
                f"Saved replacement draft UID {new_uid} but could not delete old UID {uid}. {exc}"
            ) from exc
    return draft_result(message, new_uid, replaced_uid=uid)


@mcp.tool()
def delete_draft(uid: str, confirm: bool = False) -> DeletedDraft:
    """Delete one message from Drafts by UID. Does not send.

    Requires confirm=true. Only the Drafts folder is affected. The UID must
    be a Drafts UID from search_emails(folder="Drafts") or read_draft.
    """
    if confirm is not True:
        raise ToolError(DELETE_DRAFT_CONFIRM_ERROR)
    with imap_session() as mail:
        select_folder(mail, DRAFTS_FOLDER)
        msg = fetch_uid(mail, uid)
        subject = decode_mime_header(msg.get("Subject")).strip()
        delete_draft_uid(mail, uid)
    return DeletedDraft(folder=DRAFTS_FOLDER, uid=uid, subject=subject)


@mcp.tool()
def send_email(
    subject: str,
    body: str,
    to: list[str] | None = None,
    cc: list[str] | None = None,
    bcc: list[str] | None = None,
    html: bool = False,
    in_reply_to: str | None = None,
    references: str | None = None,
    reply_uid: str | None = None,
    reply_folder: str = "INBOX",
    confirm: bool = False,
) -> SendResult:
    """Send mail through Proton Mail Bridge SMTP (127.0.0.1:1025 STARTTLS).

    Requires confirm=true. Bridge places a copy in Sent; this does not write
    Drafts. Pass reply_uid to reply to an existing message. Bcc is used only
    as an envelope recipient and is stripped from the delivered headers.
    """
    if confirm is not True:
        raise ToolError(SEND_CONFIRM_ERROR)
    config = require_config()
    if reply_uid:
        with imap_session() as mail:
            message = prepare_outgoing(
                config,
                mail=mail,
                to=to,
                cc=cc,
                bcc=bcc,
                subject=subject,
                body=body,
                html=html,
                in_reply_to=in_reply_to,
                references=references,
                reply_uid=reply_uid,
                reply_folder=reply_folder,
                require_recipient=True,
                require_body=True,
            )
    else:
        message = prepare_outgoing(
            config,
            mail=None,
            to=to,
            cc=cc,
            bcc=bcc,
            subject=subject,
            body=body,
            html=html,
            in_reply_to=in_reply_to,
            references=references,
            reply_uid=None,
            reply_folder=reply_folder,
            require_recipient=True,
            require_body=True,
        )
    recipients = envelope_recipients(message)
    result = SendResult(
        message_id=str(message["Message-ID"]),
        subject=str(message["Subject"] or ""),
        to=list(header_addresses(message, "To")),
        cc=list(header_addresses(message, "Cc")),
        bcc=list(header_addresses(message, "Bcc")),
    )
    try:
        with smtp_session(config) as client:
            client.send_message(
                message,
                from_addr=addr_spec(config.username),
                to_addrs=recipients,
            )
    except smtplib.SMTPException as exc:
        raise ToolError(f"SMTP send failed: {exc}") from exc
    return result


if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] in {"--configure", "configure"}:
        configure_main()
    else:
        mcp.run()
