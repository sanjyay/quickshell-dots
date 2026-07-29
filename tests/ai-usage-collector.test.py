#!/usr/bin/env python3
import importlib.util
import json
import os
import stat
import tempfile
import unittest
from importlib.machinery import SourceFileLoader
from pathlib import Path
from unittest import mock

SCRIPT = Path(__file__).resolve().parents[1] / "scripts" / "ai-usage-collector"
SPEC = importlib.util.spec_from_loader("ai_usage_collector", SourceFileLoader("ai_usage_collector", str(SCRIPT)))
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


class AiUsageCollectorTest(unittest.TestCase):
    def test_executable_discovery_uses_reduced_path_and_provider_locations(self):
        with tempfile.TemporaryDirectory() as directory:
            home = Path(directory)
            binary = home / ".local/bin/codex"
            binary.parent.mkdir(parents=True)
            binary.write_text("#!/bin/sh\n")
            binary.chmod(0o755)
            with mock.patch.object(MODULE, "HOME", home), mock.patch.dict(os.environ, {"PATH": "/usr/bin"}):
                self.assertEqual(MODULE.find_executable("codex"), str(binary))

    def test_missing_optional_provider_is_explicit(self):
        with mock.patch.object(MODULE, "find_executable", return_value=None):
            result = MODULE.collect_codex()
        self.assertEqual(result["status"], "unavailable")
        self.assertEqual(result["errorCode"], "executable-not-found")

    def test_unauthenticated_claude_is_explicit(self):
        with mock.patch.object(MODULE, "find_executable", return_value="/tmp/claude"), \
             mock.patch.object(MODULE, "claude_credentials", return_value=(None, "authentication-missing")):
            result = MODULE.collect_claude()
        self.assertEqual(result["status"], "unauthenticated")
        self.assertFalse(result["authenticated"])

    def test_codex_windows_preserve_multiple_limits(self):
        windows = MODULE.codex_windows({
            "primary": {"usedPercent": 37, "windowDurationMins": 300, "resetsAt": 1785250000},
            "secondary": {"usedPercent": 6, "windowDurationMins": 10080, "resetsAt": 1785850000},
        })
        self.assertEqual([item["name"] for item in windows], ["5h", "weekly"])
        self.assertEqual(windows[0]["remainingPercent"], 63.0)

    def test_malformed_window_is_not_fabricated(self):
        windows = MODULE.codex_windows({
            "primary": {"usedPercent": "bad", "windowDurationMins": 300},
            "secondary": {},
        })
        self.assertEqual(windows, [])

    def test_ansi_is_removed_before_json_parsing(self):
        value = '\x1b[32m{"id":1,"result":{"ok":true}}\x1b[0m'
        self.assertEqual(json.loads(MODULE.strip_ansi(value))["id"], 1)

    def test_timeout_is_classified(self):
        with tempfile.TemporaryDirectory() as directory, \
             mock.patch.object(MODULE, "HOME", Path(directory)), \
             mock.patch.object(MODULE, "find_executable", return_value="/tmp/codex"), \
             mock.patch.object(MODULE, "codex_rpc", side_effect=TimeoutError()), \
             mock.patch.object(MODULE, "codex_rollout", return_value=None):
            (Path(directory) / ".codex").mkdir()
            (Path(directory) / ".codex/auth.json").write_text("{}")
            result = MODULE.collect_codex()
        self.assertEqual(result["status"], "timed-out")

    def test_atomic_write_is_private_and_leaves_no_temporary_file(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "state/usage.json"
            MODULE.write_json_atomic(path, {"schemaVersion": 1})
            self.assertEqual(json.loads(path.read_text())["schemaVersion"], 1)
            self.assertEqual(stat.S_IMODE(path.stat().st_mode), 0o600)
            self.assertEqual(list(path.parent.glob(f".{path.name}.*")), [])

    def test_failed_refresh_preserves_previous_success_separately(self):
        success = {"status": "ok", "windows": [{"usedPercent": 37}], "collectedAt": "now"}
        old = MODULE.merge_result({}, success)
        failed = MODULE.failure("codex", "/tmp/codex", "command-failed", "failed", "failed")
        merged = MODULE.merge_result(old, failed)
        self.assertEqual(merged["status"], "command-failed")
        self.assertEqual(merged["lastSuccess"]["windows"][0]["usedPercent"], 37)

    def test_never_collected_has_no_last_success(self):
        record = MODULE.merge_result({}, MODULE.base_record("opencode", None))
        self.assertEqual(record["status"], "never-collected")
        self.assertIsNone(record["lastSuccess"])

    def test_timestamp_seconds_and_milliseconds_normalize_equally(self):
        self.assertEqual(MODULE.iso_epoch(1785250000), MODULE.iso_epoch(1785250000000))

    def test_diagnostics_do_not_expose_authentication_or_raw_output(self):
        state = {"schemaVersion": 1, "providers": {
            "codex": {
                "status": "ok", "executableFound": True, "collectedAt": "now",
                "errorCode": None, "source": "rpc", "token": "secret", "raw": "private",
            }
        }}
        encoded = json.dumps(MODULE.diagnostics(state))
        self.assertNotIn("secret", encoded)
        self.assertNotIn("private", encoded)


if __name__ == "__main__":
    unittest.main()
