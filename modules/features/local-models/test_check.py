"""Smoke-test modality routing without loading model weights."""

import unittest
from unittest.mock import patch

import check


class ModalityTests(unittest.TestCase):
    def test_text_only_preserves_text_and_tool_checks(self):
        responses = [
            {"content": "OK"},
            {
                "tool_calls": [
                    {
                        "id": "echo-1",
                        "function": {"name": "echo", "arguments": '{"text":"hello"}'},
                    }
                ]
            },
            {"content": "hello"},
        ]
        with (
            patch.object(check, "chat", side_effect=responses) as chat,
            patch.object(
                check,
                "request",
                return_value={
                    "data": [{"id": "text-model", "status": {"value": "loaded"}}]
                },
            ),
        ):
            check.check_model("text-model", supports_vision=False)
        self.assertEqual(chat.call_count, 3)

    def test_vision_models_still_test_images(self):
        responses = [
            {"content": "OK"},
            {
                "tool_calls": [
                    {
                        "id": "echo-1",
                        "function": {"name": "echo", "arguments": '{"text":"hello"}'},
                    }
                ]
            },
            {"content": "hello"},
            {"content": "red"},
        ]
        with (
            patch.object(check, "chat", side_effect=responses) as chat,
            patch.object(
                check,
                "request",
                return_value={
                    "data": [{"id": "vision-model", "status": {"value": "loaded"}}]
                },
            ),
        ):
            check.check_model("vision-model")
        self.assertEqual(chat.call_count, 4)
        self.assertEqual(chat.call_args.args[1][0]["content"][0]["type"], "image_url")


if __name__ == "__main__":
    unittest.main()
