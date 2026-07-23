import contextlib
import importlib.util
import io
import pathlib
import unittest

REPO = pathlib.Path(__file__).resolve().parents[1]
PATH = REPO / "versions/default/helpers/camera-switch-monitor.py"
SPEC = importlib.util.spec_from_file_location("camera_switch_monitor", PATH)
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


class CameraEventTests(unittest.TestCase):
    def setUp(self):
        self.monitor = MODULE.Monitor()

    def apply(self, event_type, code, value):
        with contextlib.redirect_stdout(io.StringIO()):
            self.monitor.apply_event(event_type, code, value)

    def test_disable_and_enable_press(self):
        self.apply(MODULE.EV_MSC, MODULE.MSC_SCAN, MODULE.SCAN_CAMERA_DISABLED)
        self.apply(MODULE.EV_KEY, MODULE.KEY_UNKNOWN, 1)
        self.assertTrue(self.monitor.known)
        self.assertFalse(self.monitor.enabled)
        self.apply(MODULE.EV_MSC, MODULE.MSC_SCAN, MODULE.SCAN_CAMERA_ENABLED)
        self.apply(MODULE.EV_KEY, MODULE.KEY_UNKNOWN, 1)
        self.assertTrue(self.monitor.enabled)
        self.assertEqual((self.monitor.raw_events, self.monitor.key_events), (4, 2))

    def test_release_and_unexpected_values_do_not_change_state(self):
        self.monitor.known, self.monitor.enabled = True, True
        self.apply(MODULE.EV_MSC, MODULE.MSC_SCAN, MODULE.SCAN_CAMERA_DISABLED)
        self.apply(MODULE.EV_KEY, MODULE.KEY_UNKNOWN, 0)
        self.apply(MODULE.EV_KEY, MODULE.KEY_UNKNOWN, 2)
        self.assertEqual((self.monitor.known, self.monitor.enabled), (True, True))

    def test_unknown_scan_does_not_make_state_known(self):
        self.apply(MODULE.EV_MSC, MODULE.MSC_SCAN, 0x999)
        self.apply(MODULE.EV_KEY, MODULE.KEY_UNKNOWN, 1)
        self.assertEqual((self.monitor.known, self.monitor.enabled), (False, False))


if __name__ == "__main__":
    unittest.main()
