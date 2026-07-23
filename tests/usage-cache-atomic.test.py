#!/usr/bin/env python3
import importlib.util
from pathlib import Path
import stat
import sys
import tempfile
import unittest

sys.dont_write_bytecode = True

SCRIPT = Path(__file__).resolve().parents[1] / "scripts" / "qs_usage_cache.py"
SPEC = importlib.util.spec_from_file_location("qs_usage_cache", SCRIPT)
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


class UsageCacheAtomicTest(unittest.TestCase):
    def test_replaces_cache_with_private_json(self):
        with tempfile.TemporaryDirectory() as directory:
            cache = Path(directory) / "nested" / "usage.json"
            MODULE.write_json_atomic(cache, {"status": "allowed", "value": 7})
            self.assertEqual(cache.read_text(), '{"status": "allowed", "value": 7}')
            self.assertEqual(stat.S_IMODE(cache.stat().st_mode), 0o600)
            self.assertEqual(list(cache.parent.glob(f".{cache.name}.*")), [])

    def test_failed_serialization_preserves_previous_cache(self):
        with tempfile.TemporaryDirectory() as directory:
            cache = Path(directory) / "usage.json"
            cache.write_text('{"status":"previous"}')
            with self.assertRaises(TypeError):
                MODULE.write_json_atomic(cache, {"invalid": object()})
            self.assertEqual(cache.read_text(), '{"status":"previous"}')
            self.assertEqual(list(cache.parent.glob(f".{cache.name}.*")), [])


if __name__ == "__main__":
    unittest.main()
