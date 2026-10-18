"""Check saved local-models timings; never run inference or change the system."""

import argparse
import json
import math
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Any


@dataclass(frozen=True)
class Criteria:
    model: str
    context: int
    free_before_mib: int
    free_after_mib: int
    target: float = 15.0
    minimum_free_mib: int = 1536
    min_runs: int = 2
    min_generated: int = 512


@dataclass(frozen=True)
class Verdict:
    accepted: bool
    reasons: tuple[str, ...]
    minimum_decode_tok_s: float | None
    runs: int


def evaluate(report: dict[str, Any], criteria: Criteria) -> Verdict:
    """Require complete near-full input, per-run speed, and measured headroom."""
    samples = report["models"][criteria.model]["samples"]
    expected_input = criteria.context - 768
    generated = report["tokens_per_run"]
    reasons = []
    if report.get("prompt_tokens") != expected_input:
        reasons.append(f"Expected explicit {expected_input}-token input budget")
    if len(samples) < criteria.min_runs:
        reasons.append(f"Need at least {criteria.min_runs} measured runs")
    if generated < criteria.min_generated or generated > 768:
        reasons.append("Output budget is too small or exceeds reserved context space")
    if (
        min(criteria.free_before_mib, criteria.free_after_mib)
        < criteria.minimum_free_mib
    ):
        reasons.append(f"Free VRAM fell below {criteria.minimum_free_mib} MiB")
    rates = []
    for index, sample in enumerate(samples, start=1):
        rate = sample["predicted_per_second"]
        if not math.isfinite(rate) or rate < criteria.target:
            reasons.append(
                f"Run {index}: decode rate does not meet {criteria.target} tok/s"
            )
        if math.isfinite(rate):
            rates.append(rate)
        if sample["prompt_n"] != expected_input:
            reasons.append(f"Run {index}: input was not fully evaluated")
        if sample["predicted_n"] != generated:
            reasons.append(f"Run {index}: incomplete generation")
        if sample.get("truncated", False):
            reasons.append(f"Run {index}: truncated context")
    return Verdict(
        accepted=not reasons,
        reasons=tuple(reasons),
        minimum_decode_tok_s=min(rates) if rates else None,
        runs=len(samples),
    )


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("report", type=Path)
    parser.add_argument("--model", required=True)
    parser.add_argument("--context", type=int, required=True)
    parser.add_argument("--target", type=float, default=15.0)
    parser.add_argument("--minimum-free-mib", type=int, default=1536)
    parser.add_argument("--free-before-mib", type=int, required=True)
    parser.add_argument("--free-after-mib", type=int, required=True)
    parser.add_argument("--min-runs", type=int, default=2)
    parser.add_argument("--min-generated", type=int, default=512)
    args = parser.parse_args()
    if (
        args.context <= 8192
        or not math.isfinite(args.target)
        or args.target <= 0
        or args.min_runs <= 0
        or not 0 < args.min_generated <= 768
        or min(args.minimum_free_mib, args.free_before_mib, args.free_after_mib) < 0
    ):
        parser.error("Invalid context, speed, run count, output budget, or VRAM value")
    criteria = Criteria(
        **{key: value for key, value in vars(args).items() if key != "report"}
    )
    try:
        report = json.loads(args.report.read_text())
        verdict = evaluate(report, criteria)
    except (OSError, ValueError, KeyError, TypeError, OverflowError) as error:
        parser.exit(2, f"Cannot validate report: {error}\n")
    print(json.dumps(asdict(verdict), indent=2, allow_nan=False))
    return 0 if verdict.accepted else 1


if __name__ == "__main__":
    raise SystemExit(main())
