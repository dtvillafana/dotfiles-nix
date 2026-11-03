#!@python313@/bin/python3
from __future__ import annotations

import html
import json
import re
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


def plain_text_to_html(body: str) -> str:
    paragraphs = re.split(r"\n\s*\n", body.replace("\r\n", "\n").strip())
    return "".join(
        "<p>" + html.escape(paragraph.strip()).replace("\n", "<br>\n") + "</p>"
        for paragraph in paragraphs
        if paragraph.strip()
    )


def with_html_body(tool_input: dict[str, Any]) -> dict[str, Any]:
    updated = dict(tool_input)
    for key in BODY_KEYS:
        value = updated.get(key)
        if not isinstance(value, str) or not value.strip():
            continue
        if not looks_like_html(value, body_type_of(updated)):
            updated[key] = plain_text_to_html(value)
        if key == "body":
            updated["bodyType"] = "HTML"
        break
    return updated


def with_footer(tool_input: dict[str, Any]) -> dict[str, Any]:
    if not recipients_are_internal(tool_input):
        return tool_input
    updated = dict(tool_input)
    body_type = body_type_of(updated)
    for key in BODY_KEYS:
        value = updated.get(key)
        if isinstance(value, str):
            updated[key] = append_footer(value, looks_like_html(value, body_type))
            return updated
    updated["body"] = append_footer("", looks_like_html("", body_type))
    return updated


def main() -> None:
    try:
        data = json.load(sys.stdin)
    except json.JSONDecodeError:
        raise SystemExit(0)

    tool_input = data.get("tool_input")
    if not isinstance(tool_input, dict):
        raise SystemExit(0)

    updated = with_footer(with_html_body(tool_input))
    if updated == tool_input:
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
