#!/usr/bin/env python3
import importlib.util
from importlib.machinery import SourceFileLoader
from pathlib import Path
import sys
import unittest

sys.dont_write_bytecode = True

SCRIPT = Path(__file__).resolve().parents[1] / "scripts" / "codex-usage"
SPEC = importlib.util.spec_from_loader("codex_usage", SourceFileLoader("codex_usage", str(SCRIPT)))
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


class CodexUsageNormalizationTest(unittest.TestCase):
    def test_weekly_primary_is_not_mislabeled_as_five_hour(self):
        weekly = {"usedPercent": 18, "windowDurationMins": 10080, "resetsAt": 1784795580}
        short, normalized_weekly = MODULE.normalize_windows({"primary": weekly, "secondary": None})
        self.assertIsNone(short)
        self.assertEqual(normalized_weekly, weekly)

    def test_windows_are_classified_by_duration_not_position(self):
        weekly = {"usedPercent": 18, "windowDurationMins": 10080}
        short = {"usedPercent": 50, "windowDurationMins": 300}
        normalized_short, normalized_weekly = MODULE.normalize_windows(
            {"primary": weekly, "secondary": short}
        )
        self.assertEqual(normalized_short, short)
        self.assertEqual(normalized_weekly, weekly)

    def test_explicit_zero_credit_balance_is_available(self):
        self.assertEqual(MODULE.credit_balance({"hasCredits": False, "balance": "0"}), (True, "0"))
        self.assertEqual(MODULE.credit_balance(None), (False, ""))


if __name__ == "__main__":
    unittest.main()
