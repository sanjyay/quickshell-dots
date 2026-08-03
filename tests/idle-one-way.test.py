#!/usr/bin/env python3
"""Behavioral contract for Astra's one-way native idle observer."""

import unittest


class NativeIdle:
    def __init__(self, stay_awake=False):
        self.stay_awake = stay_awake
        self.calls = 0

    def set_idle_enabled(self, enabled):
        self.calls += 1
        self.stay_awake = not enabled


class AstraObserver:
    def __init__(self, backend):
        self.backend = backend

    @property
    def awake(self):
        return self.backend.stay_awake

    def click(self):
        self.backend.set_idle_enabled(self.awake)


class IdleOneWayContract(unittest.TestCase):
    def test_external_change_updates_ui_without_writeback(self):
        native = NativeIdle(False)
        astra = AstraObserver(native)
        native.stay_awake = True
        self.assertTrue(astra.awake)
        self.assertEqual(native.calls, 0)

    def test_one_click_calls_backend_once(self):
        native = NativeIdle(False)
        astra = AstraObserver(native)
        astra.click()
        self.assertTrue(astra.awake)
        self.assertEqual(native.calls, 1)

    def test_recreation_adopts_state_without_writeback(self):
        native = NativeIdle(True)
        astra = AstraObserver(native)
        self.assertTrue(astra.awake)
        self.assertEqual(native.calls, 0)


if __name__ == "__main__":
    unittest.main()
