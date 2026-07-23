import importlib.util
import json
import os
import pathlib
import subprocess
import tempfile
import unittest
from unittest import mock


REPO = pathlib.Path(__file__).resolve().parents[1]
SCANNER = REPO / "versions/default/helpers/app-launcher-scan.py"
PANEL = REPO / "versions/default/panels/AppLauncherPanel.qml"
SPEC = importlib.util.spec_from_file_location("app_launcher_scan", SCANNER)
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


class LauncherScannerTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = pathlib.Path(self.temp.name)
        self.first = self.root / "first"
        self.second = self.root / "second"
        self.icons = self.root / "icons/theme/48x48/apps"
        self.cache = self.root / "cache/apps.json"
        self.first.mkdir(parents=True)
        self.second.mkdir(parents=True)
        self.icons.mkdir(parents=True)

    def tearDown(self):
        self.temp.cleanup()

    def desktop(self, directory, filename, body):
        path = directory / filename
        path.write_text("[Desktop Entry]\n" + body, encoding="utf-8")
        return path

    def run_scanner(self):
        command = [
            "python3", "-B", str(SCANNER), "--cache", str(self.cache),
            "--application-dir", str(self.first), "--application-dir", str(self.second),
            "--icon-dir", str(self.root / "icons"),
        ]
        result = subprocess.run(command, check=True, text=True, capture_output=True,
                                env={**os.environ, "HOME": str(self.root / "home")})
        return json.loads(result.stdout), result.stderr

    def test_precedence_filtering_icon_and_schema(self):
        icon = self.icons / "alpha.svg"
        icon.write_text("<svg/>\n", encoding="utf-8")
        preferred = self.desktop(self.first, "alpha.desktop", "Name=Alpha\nExec=alpha-first %U\nIcon=alpha\nCategories=Utility;\nKeywords=one;two;\n")
        self.desktop(self.second, "alpha.desktop", "Name=Alpha\nExec=alpha-second\n")
        self.desktop(self.first, "zulu.desktop", "Name=zulu\nExec=zulu\nIcon=missing-icon\n")
        self.desktop(self.first, "hidden.desktop", "Name=Hidden\nExec=hidden\nHidden=true\n")
        self.desktop(self.first, "nodisplay.desktop", "Name=No Display\nExec=no-display\nNoDisplay=TRUE\n")
        self.desktop(self.first, "btop.desktop", "Name=Monitor\nExec=btop\n")
        self.desktop(self.first, "missing.desktop", "Name=Missing Exec\n")
        (self.first / "malformed.desktop").write_bytes(b"\xff\xfe\x00")

        payload, stderr = self.run_scanner()
        self.assertEqual(payload["version"], 1)
        self.assertIsInstance(payload["generatedAt"], int)
        self.assertEqual([app["name"] for app in payload["apps"]], ["Alpha", "zulu"])
        alpha = payload["apps"][0]
        self.assertEqual(alpha["exec"], "alpha-first %U")
        self.assertEqual(alpha["file"], str(preferred))
        self.assertEqual(alpha["icon"], str(icon))
        self.assertEqual(alpha["categories"], "Utility;")
        self.assertEqual(alpha["keywords"], "one;two;")
        self.assertEqual(set(alpha), {"name", "exec", "icon", "file", "categories", "keywords", "mtime"})
        self.assertEqual(payload["apps"][1]["icon"], "missing-icon")
        self.assertIn("cache write success count=2", stderr)

    def test_cache_matches_stdout_and_is_atomically_replaced(self):
        self.desktop(self.first, "alpha.desktop", "Name=Alpha\nExec=alpha\n")
        self.cache.parent.mkdir(parents=True)
        self.cache.write_text('{"stale":true}\n', encoding="utf-8")
        payload, _stderr = self.run_scanner()
        self.assertEqual(json.loads(self.cache.read_text(encoding="utf-8")), payload)
        self.assertEqual(list(self.cache.parent.glob("apps.*.json.tmp")), [])

    def test_failed_replace_preserves_previous_cache(self):
        self.cache.parent.mkdir(parents=True)
        self.cache.write_text('{"stale":true}\n', encoding="utf-8")
        with mock.patch.object(MODULE.os, "replace", side_effect=OSError("fixture failure")):
            with self.assertRaises(OSError):
                MODULE.write_cache(str(self.cache), {"version": 1, "apps": []})
        self.assertEqual(json.loads(self.cache.read_text(encoding="utf-8")), {"stale": True})
        self.assertEqual(list(self.cache.parent.glob("apps.*.json.tmp")), [])

    def test_qml_is_only_the_scanner_adapter(self):
        source = PANEL.read_text(encoding="utf-8")
        self.assertIn('Qt.resolvedUrl("../helpers/app-launcher-scan.py")', source)
        self.assertIn('["python3", "-u", appPanel.scannerPath, "--cache", appPanel.cachePath]', source)
        self.assertNotIn("import configparser, json, os", source)
        self.assertNotIn("python3 -c", source)


if __name__ == "__main__":
    unittest.main()
