"""Offline regression tests; never connect to an inference service."""

import argparse
import unittest
from unittest.mock import patch

from benchmark import benchmark, summarize


class BenchmarkTests(unittest.TestCase):
    def test_weighted_decode_not_arithmetic_mean(self) -> None:
        samples = [
            {
                "predicted_n": 100,
                "predicted_ms": elapsed,
                "prompt_n": 50,
                "prompt_ms": 500,
                "wall_seconds": elapsed / 1000 + 0.5,
            }
            for elapsed in (1000, 9000)
        ]
        result = summarize(samples, 15)
        self.assertEqual(result["generation_tok_s"], 20)
        self.assertEqual(result["prefill_tok_s"], 100)
        self.assertTrue(result["passes_decode_target"])
        self.assertLess(result["warm_wall_tok_s"], 20)

    def test_target_is_strictly_greater_than_fifteen(self) -> None:
        result = summarize(
            [
                {
                    "predicted_n": 15,
                    "predicted_ms": 1000,
                    "prompt_n": 0,
                    "prompt_ms": 0,
                    "wall_seconds": 1,
                }
            ],
            15,
        )
        self.assertFalse(result["passes_decode_target"])

    def test_missing_generation_rejected(self) -> None:
        with self.assertRaises(ValueError):
            summarize(
                [
                    {
                        "predicted_n": 0,
                        "predicted_ms": 0,
                        "prompt_n": 0,
                        "prompt_ms": 0,
                        "wall_seconds": 1,
                    }
                ],
                15,
            )

    @patch("builtins.print")
    @patch("benchmark.request")
    def test_warmup_excluded_and_samples_uncached(
        self, request_mock, print_mock
    ) -> None:
        request_mock.return_value = {
            "timings": {
                "predicted_n": 512,
                "predicted_ms": 10000,
                "prompt_n": 100,
                "prompt_ms": 100,
                "predicted_per_second": 51.2,
            }
        }
        args = argparse.Namespace(
            runs=2, tokens=512, prompt_repeats=8, prompt_tokens=None, target=15
        )
        result = benchmark("http://unused", "test-model", args)
        self.assertEqual(len(result["samples"]), 2)
        self.assertEqual(request_mock.call_count, 3)
        bodies = [call.args[2] for call in request_mock.call_args_list]
        self.assertEqual([body["n_predict"] for body in bodies], [32, 512, 512])
        self.assertTrue(all(not body["cache_prompt"] for body in bodies))
        self.assertNotEqual(bodies[1]["prompt"], bodies[2]["prompt"])
        self.assertIn("100 prefill tokens in 0.10s", print_mock.call_args.args[0])

    @patch("benchmark.request")
    def test_exact_token_budget(self, request_mock) -> None:
        sample = {
            "timings": {
                "predicted_n": 256,
                "predicted_ms": 10000,
                "prompt_n": 32000,
                "prompt_ms": 100,
                "predicted_per_second": 25.6,
            }
        }
        request_mock.side_effect = [{}, {"tokens": [100, 101, 102]}, sample, sample]
        args = argparse.Namespace(
            runs=2, tokens=256, prompt_repeats=8, prompt_tokens=32000, target=15
        )
        result = benchmark("http://unused", "test-model", args)
        self.assertEqual(len(result["samples"]), 2)
        self.assertEqual(request_mock.call_args_list[1].args[1], "/tokenize")
        prompts = [call.args[2]["prompt"] for call in request_mock.call_args_list[2:]]
        self.assertTrue(all(len(prompt) == 32000 for prompt in prompts))
        self.assertNotEqual(prompts[0], prompts[1])

    @patch("benchmark.request")
    def test_truncated_or_cached_long_prompt_rejected(self, request_mock) -> None:
        args = argparse.Namespace(
            runs=1, tokens=256, prompt_repeats=8, prompt_tokens=32000, target=15
        )
        for truncated, prompt_n in ((True, 32000), (False, 31999)):
            with self.subTest(truncated=truncated, prompt_n=prompt_n):
                request_mock.side_effect = [
                    {},
                    {"tokens": [100, 101]},
                    {
                        "truncated": truncated,
                        "timings": {"predicted_n": 256, "prompt_n": prompt_n},
                    },
                ]
                with self.assertRaises(ValueError):
                    benchmark("http://unused", "test-model", args)


if __name__ == "__main__":
    unittest.main()
