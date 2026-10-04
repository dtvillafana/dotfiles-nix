#!@python313@/bin/python3
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
