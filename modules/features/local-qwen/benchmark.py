"""Measure the active router's decode throughput; no model-quality claims."""

import argparse
import json
import time
import urllib.error
import urllib.request
from pathlib import Path


def request(base_url: str, path: str, body: dict | None = None) -> dict:
    data = None if body is None else json.dumps(body).encode()
    req = urllib.request.Request(
        base_url + path, data=data, headers={"Content-Type": "application/json"}
    )
    with urllib.request.urlopen(req, timeout=3600) as response:
        return json.load(response)


def summarize(samples: list[dict], target: float) -> dict:
    generated = sum(sample["predicted_n"] for sample in samples)
    generation_ms = sum(sample["predicted_ms"] for sample in samples)
    prompt_tokens = sum(sample["prompt_n"] for sample in samples)
    prompt_ms = sum(sample["prompt_ms"] for sample in samples)
    if generated <= 0 or generation_ms <= 0:
        raise ValueError("Server did not return usable generation timings")
    decode = generated * 1000 / generation_ms
    return {
        "generation_tok_s": decode,
        "prefill_tok_s": prompt_tokens * 1000 / prompt_ms if prompt_ms > 0 else None,
        "warm_wall_tok_s": generated
        / sum(sample["wall_seconds"] for sample in samples),
        "generated_tokens": generated,
        "passes_decode_target": decode > target,
        "samples": samples,
    }


def benchmark(base_url: str, model: str, args: argparse.Namespace) -> dict:
    # A unique prefix plus cache_prompt=false prevents cached-prefix prefill
    # from being mistaken for real prompt processing. ignore_eos fixes length.
    prompt = (
        "Review this software design and explain its tradeoffs with examples.\n"
        + "The service queues jobs, retries failures, validates inputs, and records audit events. "
        * args.prompt_repeats
    )
    body = {
        "model": model,
        "prompt": prompt,
        "n_predict": 32,
        "temperature": 0,
        "seed": 42,
        "ignore_eos": True,
        "cache_prompt": False,
        "stream": False,
    }
    print(f"{model}: loading/warming (excluded from timings)...", flush=True)
    request(base_url, "/completion", body)
    prompt_tokens = None
    if args.prompt_tokens is not None:
        # Token arrays let long-context trials fill an exact input budget.
        tokens = request(base_url, "/tokenize", {"model": model, "content": prompt})[
            "tokens"
        ]
        if not tokens:
            raise ValueError("Tokenizer returned no tokens")
        prompt_tokens = (tokens * (args.prompt_tokens // len(tokens) + 1))[
            : args.prompt_tokens
        ]
    samples = []
    for run in range(args.runs):
        start = time.monotonic()
        result = request(
            base_url,
            "/completion",
            {
                **body,
                "prompt": (
                    [prompt_tokens[0] + run, *prompt_tokens[1:]]
                    if prompt_tokens is not None
                    else f"Trial {run} at {time.monotonic_ns()}\n" + prompt
                ),
                "n_predict": args.tokens,
            },
        )
        elapsed = time.monotonic() - start
        timings = result["timings"]
        if timings["predicted_n"] != args.tokens:
            raise ValueError(f"{model}: incomplete generation: {timings}")
        if args.prompt_tokens is not None and result.get("truncated", False):
            raise ValueError(f"{model}: prompt was truncated")
        if args.prompt_tokens is not None and timings["prompt_n"] != args.prompt_tokens:
            raise ValueError(
                f"{model}: input budget was not fully evaluated: {timings}"
            )
        samples.append({**timings, "wall_seconds": elapsed})
        print(
            f"  run {run + 1}: {timings['predicted_per_second']:.2f} decode tok/s; "
            f"{timings['prompt_n']} prefill tokens",
            flush=True,
        )
    return summarize(samples, args.target)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--base-url", default="http://127.0.0.1:18082")
    parser.add_argument(
        "--model", action="append", help="Model ID; repeat to select several"
    )
    parser.add_argument("--runs", type=int, default=3)
    parser.add_argument("--tokens", type=int, default=512)
    parser.add_argument("--prompt-repeats", type=int, default=64)
    parser.add_argument("--prompt-tokens", type=int, help="Exact input token budget")
    parser.add_argument("--target", type=float, default=15.0)
    parser.add_argument("--json", type=Path, help="Save full measurements to this file")
    args = parser.parse_args()
    if min(args.runs, args.tokens, args.prompt_repeats) <= 0 or args.target <= 0:
        parser.error("Runs, tokens, prompt repeats, and target must be positive")
    if args.prompt_tokens is not None and args.prompt_tokens <= 0:
        parser.error("Prompt token budget must be positive")
    models = args.model or sorted(
        item["id"] for item in request(args.base_url, "/v1/models")["data"]
    )
    if not models:
        raise ValueError("Router advertised no models")
    results = {model: benchmark(args.base_url, model, args) for model in models}
    report = {
        "target_generation_tok_s": args.target,
        "runs": args.runs,
        "tokens_per_run": args.tokens,
        "prompt_repeats": args.prompt_repeats,
        "prompt_tokens": args.prompt_tokens,
        "models": results,
    }
    if args.json:
        args.json.write_text(json.dumps(report, indent=2) + "\n")
    for model, result in results.items():
        status = "PASS" if result["passes_decode_target"] else "BELOW TARGET"
        print(
            f"{model}: {result['generation_tok_s']:.2f} decode tok/s; "
            f"{result['warm_wall_tok_s']:.2f} wall tok/s — {status}"
        )
    return (
        0 if all(result["passes_decode_target"] for result in results.values()) else 1
    )


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (urllib.error.URLError, TimeoutError, ValueError, KeyError) as error:
        raise SystemExit(f"FAIL: {error}") from error
