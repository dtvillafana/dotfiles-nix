"""Sequential smoke tests for the local Qwen router (standard library only)."""

import base64
import json
import struct
import time
import urllib.error
import urllib.request
import zlib

BASE_URL = "http://127.0.0.1:18082"
MODELS = (
    "qwen3.5-9b-abliterated",
    "qwen3.6-35b-a3b-abliterated",
    "qwen3.8-27b-abliterated",
)


def request(path: str, body: dict | None = None) -> dict:
    data = None if body is None else json.dumps(body).encode()
    req = urllib.request.Request(
        BASE_URL + path, data=data, headers={"Content-Type": "application/json"}
    )
    with urllib.request.urlopen(req, timeout=3600) as response:
        return json.load(response)


def chat(model: str, messages: list[dict], **kwargs: object) -> dict:
    result = request(
        "/v1/chat/completions",
        {
            "model": model,
            "messages": messages,
            "max_tokens": 256,
            "temperature": 0,
            "chat_template_kwargs": {"enable_thinking": False},
            **kwargs,
        },
    )
    return result["choices"][0]["message"]


def png_chunk(kind: bytes, data: bytes) -> bytes:
    return (
        struct.pack(">I", len(data))
        + kind
        + data
        + struct.pack(">I", zlib.crc32(kind + data))
    )


def red_image() -> str:
    header = struct.pack(">IIBBBBB", 64, 64, 8, 2, 0, 0, 0)
    pixels = (b"\x00" + b"\xff\x00\x00" * 64) * 64
    image = (
        b"\x89PNG\r\n\x1a\n"
        + png_chunk(b"IHDR", header)
        + png_chunk(b"IDAT", zlib.compress(pixels))
        + png_chunk(b"IEND", b"")
    )
    return "data:image/png;base64," + base64.b64encode(image).decode()


def check_model(model: str) -> None:
    start = time.monotonic()
    print(f"{model}: loading and testing text...", flush=True)
    answer = chat(model, [{"role": "user", "content": "Reply with exactly OK."}])
    if "OK" not in (answer.get("content") or ""):
        raise ValueError(f"Unexpected text response: {answer}")

    messages = [{"role": "user", "content": "Call echo with text 'hello'."}]
    tool = {
        "type": "function",
        "function": {
            "name": "echo",
            "description": "Return the supplied text.",
            "parameters": {
                "type": "object",
                "properties": {"text": {"type": "string"}},
                "required": ["text"],
                "additionalProperties": False,
            },
        },
    }
    print(f"{model}: testing tool call and follow-up...", flush=True)
    call = chat(model, messages, tools=[tool], tool_choice="required")
    calls = call.get("tool_calls", [])
    if len(calls) != 1 or calls[0]["function"]["name"] != "echo":
        raise ValueError(f"Unexpected tool response: {call}")
    args = json.loads(calls[0]["function"]["arguments"])
    if args != {"text": "hello"}:
        raise ValueError(f"Unexpected tool arguments: {args}")
    followup = chat(
        model,
        [
            *messages,
            call,
            {"role": "tool", "tool_call_id": calls[0]["id"], "content": "hello"},
        ],
        tools=[tool],
        tool_choice="none",
    )
    if not followup.get("content") or followup.get("tool_calls"):
        raise ValueError(f"Unexpected tool follow-up: {followup}")

    print(f"{model}: testing vision...", flush=True)
    vision = chat(
        model,
        [
            {
                "role": "user",
                "content": [
                    {"type": "image_url", "image_url": {"url": red_image()}},
                    {"type": "text", "text": "What color is this image? One word."},
                ],
            }
        ],
    )
    if "red" not in (vision.get("content") or "").lower():
        raise ValueError(f"Unexpected vision response: {vision}")
    loaded = [
        item["id"]
        for item in request("/models")["data"]
        if item.get("status", {}).get("value") == "loaded"
    ]
    if loaded != [model]:
        raise ValueError(f"Expected only {model} resident, got {loaded}")
    print(f"{model}: PASS ({time.monotonic() - start:.1f}s)", flush=True)


if __name__ == "__main__":
    try:
        for model in MODELS:
            check_model(model)
    except (urllib.error.URLError, TimeoutError, ValueError, KeyError, IndexError) as error:
        raise SystemExit(f"FAIL: {error}") from error
