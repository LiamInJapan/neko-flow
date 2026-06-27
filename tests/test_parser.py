#!/usr/bin/env python3
"""Basic parser tests for Neko Flow."""
from __future__ import annotations

import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
PARSER = REPO / "lib" / "neko_flow_doc_parse.py"

SAMPLE = """\
[COMMS]
@DESC Triage messages
@ROUTINE Routine
- Team Slack - Check threads [SlackMain]
- Email [GmailInbox]

[WORK]
@ROUTINE Routine
- Deep work
"""


class ParserTests(unittest.TestCase):
    def run_parser(self, cmd: str, mode: str = "COMMS", extra: list[str] | None = None) -> str:
        env = os.environ.copy()
        with tempfile.TemporaryDirectory() as td:
            modes = Path(td) / "flow_modes.txt"
            modes.write_text(SAMPLE, encoding="utf-8")
            env["NEKO_FLOW_MODES"] = str(modes)
            env["NEKO_FLOW_CONFIG_DIR"] = td
            args = [sys.executable, str(PARSER), cmd, mode] + (extra or [])
            return subprocess.check_output(args, env=env, text=True)

    def test_modes_order(self):
        env = os.environ.copy()
        with tempfile.TemporaryDirectory() as td:
            modes = Path(td) / "flow_modes.txt"
            modes.write_text(SAMPLE, encoding="utf-8")
            env["NEKO_FLOW_MODES"] = str(modes)
            out = subprocess.check_output(
                [sys.executable, str(PARSER), "modes"],
                env=env,
                text=True,
            )
        self.assertEqual(out.strip().splitlines(), ["COMMS", "WORK"])

    def test_meta_buttons(self):
        raw = self.run_parser("meta", "COMMS")
        data = json.loads(raw)
        self.assertIn("Team Slack", data["options"])
        buttons = data["layout"]["optionButtons"]
        self.assertIn("0", buttons)
        self.assertEqual(buttons["0"], ["SlackMain"])
        self.assertEqual(data["layout"]["modeDescription"], "Triage messages")


if __name__ == "__main__":
    unittest.main()
