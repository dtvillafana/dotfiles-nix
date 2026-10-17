"""Offline checks for acceptance rules; no GPU, API, or rebuild required."""

import unittest
from dataclasses import replace

from check_trial import Criteria, evaluate


def make_report(rates: tuple[float, ...] = (15.78, 15.83)) -> dict:
    return {
        "prompt_tokens": 44288,
        "tokens_per_run": 512,
        "models": {
            "test": {
                "generation_tok_s": 20,
                "passes_decode_target": True,
                "samples": [
                    {
                        "predicted_per_second": rate,
                        "prompt_n": 44288,
                        "predicted_n": 512,
                    }
                    for rate in rates
                ],
            }
        },
    }


class TrialTests(unittest.TestCase):
    def setUp(self) -> None:
        self.criteria = Criteria("test", 45056, 1700, 1680)

    def test_pass_and_minimum_rate(self) -> None:
        verdict = evaluate(make_report(), self.criteria)
        self.assertTrue(verdict.accepted)
        self.assertEqual(verdict.minimum_decode_tok_s, 15.78)

    def test_minimum_inclusive_not_aggregate(self) -> None:
        self.assertTrue(evaluate(make_report((15, 15)), self.criteria).accepted)
        self.assertFalse(evaluate(make_report((30, 14.9)), self.criteria).accepted)

    def test_free_vram_both_before_and_after(self) -> None:
        for before, after in ((1516, 1700), (1700, 1516)):
            with self.subTest(before=before, after=after):
                criteria = replace(
                    self.criteria, free_before_mib=before, free_after_mib=after
                )
                self.assertFalse(evaluate(make_report(), criteria).accepted)

    def test_nonfinite_rates(self) -> None:
        for rate in (float("nan"), float("inf"), float("-inf")):
            with self.subTest(rate=rate):
                self.assertFalse(
                    evaluate(make_report((rate, 20)), self.criteria).accepted
                )

    def test_short_prompt_or_cached_input_rejected(self) -> None:
        for field in ("prompt_tokens", "prompt_n"):
            report = make_report()
            if field == "prompt_tokens":
                report[field] = None
            else:
                report["models"]["test"]["samples"][0][field] = 1000
            self.assertFalse(evaluate(report, self.criteria).accepted)

    def test_incomplete_or_truncated_output(self) -> None:
        for field, value in (("predicted_n", 256), ("truncated", True)):
            report = make_report()
            report["models"]["test"]["samples"][0][field] = value
            self.assertFalse(evaluate(report, self.criteria).accepted)

    def test_final_validation_requires_two_long_generations(self) -> None:
        self.assertFalse(evaluate(make_report((16,)), self.criteria).accepted)
        report = make_report()
        report["tokens_per_run"] = 256
        self.assertFalse(evaluate(report, self.criteria).accepted)

    def test_exploratory_criteria(self) -> None:
        report = make_report((16,))
        report["tokens_per_run"] = 256
        report["models"]["test"]["samples"][0]["predicted_n"] = 256
        criteria = replace(self.criteria, min_runs=1, min_generated=256)
        self.assertTrue(evaluate(report, criteria).accepted)


if __name__ == "__main__":
    unittest.main()
