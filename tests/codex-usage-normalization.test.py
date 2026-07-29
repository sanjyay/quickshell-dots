#!/usr/bin/env python3
import importlib.util
from importlib.machinery import SourceFileLoader
from pathlib import Path
import sys
import unittest
import unittest.mock

sys.dont_write_bytecode = True

SCRIPT = Path(__file__).resolve().parents[1] / "scripts" / "ai-usage-collector"
SPEC = importlib.util.spec_from_loader("codex_usage", SourceFileLoader("codex_usage", str(SCRIPT)))
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


class CodexUsageNormalizationTest(unittest.TestCase):
    def test_weekly_primary_is_not_mislabeled_as_five_hour(self):
        weekly = {"usedPercent": 18, "windowDurationMins": 10080, "resetsAt": 1784795580}
        normalized = MODULE.codex_windows({"primary": weekly, "secondary": None})
        self.assertEqual([item["name"] for item in normalized], ["weekly"])

    def test_windows_are_classified_by_duration_not_position(self):
        weekly = {"usedPercent": 18, "windowDurationMins": 10080}
        short = {"usedPercent": 50, "windowDurationMins": 300}
        normalized = MODULE.codex_windows({"primary": weekly, "secondary": short})
        self.assertEqual([item["name"] for item in normalized], ["weekly", "5h"])

    def test_explicit_zero_credit_balance_is_available(self):
        data = {"primary": None, "secondary": None, "credits": {"hasCredits": False, "balance": "0"}}
        with unittest.mock.patch.object(MODULE, "find_executable", return_value="/tmp/codex"), \
             unittest.mock.patch.object(MODULE, "codex_rpc", return_value=data), \
             unittest.mock.patch.object(MODULE.Path, "is_file", return_value=True):
            result = MODULE.collect_codex()
        self.assertTrue(result["details"]["creditsAvailable"])
        self.assertEqual(result["details"]["creditsRemaining"], "0")


if __name__ == "__main__":
    unittest.main()
