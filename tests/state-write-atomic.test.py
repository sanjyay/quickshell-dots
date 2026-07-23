#!/usr/bin/env python3
import importlib.machinery
import importlib.util
import json
from pathlib import Path
import stat
import subprocess
import sys
import tempfile
import unittest


SCRIPT = Path(__file__).resolve().parents[1] / "scripts" / "qs-state-write"
loader = importlib.machinery.SourceFileLoader("qs_state_write", str(SCRIPT))
spec = importlib.util.spec_from_loader(loader.name, loader)
MODULE = importlib.util.module_from_spec(spec)
loader.exec_module(MODULE)


class AtomicStateWriterTest(unittest.TestCase):
    def test_writes_valid_private_json(self):
        with tempfile.TemporaryDirectory() as directory:
            target = Path(directory) / "nested" / "notifications.json"
            payload = '{"recent":[{"summary":"hello"}]}'
            MODULE.write_json_atomic(target, payload)
            self.assertEqual(json.loads(target.read_text()), json.loads(payload))
            self.assertEqual(stat.S_IMODE(target.stat().st_mode), 0o600)
            self.assertEqual(list(target.parent.glob(f".{target.name}.*")), [])

    def test_invalid_json_preserves_previous_file(self):
        with tempfile.TemporaryDirectory() as directory:
            target = Path(directory) / "notifications.json"
            target.write_text('{"recent":[{"summary":"previous"}]}')
            with self.assertRaises(json.JSONDecodeError):
                MODULE.write_json_atomic(target, "{invalid")
            self.assertEqual(target.read_text(), '{"recent":[{"summary":"previous"}]}')
            self.assertEqual(list(target.parent.glob(f".{target.name}.*")), [])

    def test_cli_preserves_exact_text_and_validates_json_mode(self):
        with tempfile.TemporaryDirectory() as directory:
            target = Path(directory) / "state"
            subprocess.run(
                [sys.executable, "-B", str(SCRIPT), str(target)],
                input=json.dumps({"data": "legacy fields\n"}) + "\n",
                text=True,
                check=True,
            )
            self.assertEqual(target.read_bytes(), b"legacy fields\n")

            failed = subprocess.run(
                [sys.executable, "-B", str(SCRIPT), "--json", str(target)],
                input=json.dumps({"data": "{invalid"}) + "\n",
                text=True,
                capture_output=True,
            )
            self.assertNotEqual(failed.returncode, 0)
            self.assertEqual(target.read_bytes(), b"legacy fields\n")


if __name__ == "__main__":
    unittest.main()
