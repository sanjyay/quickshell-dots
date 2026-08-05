#!/usr/bin/env node
const assert = require("assert")
const model = require("../versions/default/services/DisplayModel.js")

assert.strictEqual(model.clampBrightness(-20), 1)
assert.strictEqual(model.clampBrightness(50.4), 50)
assert.strictEqual(model.clampBrightness(400), 100)
assert.strictEqual(model.clampBrightness("bad"), 1)

const fixture = JSON.stringify([
  { name: "DP-2", description: "External", width: 2560, height: 1440,
    refreshRate: 143.99, x: 1920, y: 0, scale: 1.6, transform: 1,
    mirrorOf: "none", currentFormat: "XRGB2101010", disabled: false },
  { name: "eDP-1", description: "Internal", width: 1920, height: 1080,
    refreshRate: 60, x: 0, y: 0, scale: 1.25, transform: 0,
    mirrorOf: "none", currentFormat: "XRGB8888", disabled: false }
])
const parsed = model.parseMonitors(fixture, "eDP-1")
assert.strictEqual(parsed.ok, true)
assert.strictEqual(parsed.monitors.length, 2)
assert.strictEqual(parsed.selected.name, "eDP-1")
assert.strictEqual(parsed.selected.description, "Internal")
assert.strictEqual(parsed.selected.scale, "1.25")
assert.strictEqual(model.parseMonitors("not-json", "eDP-1").error, "malformed-monitor-json")
assert.strictEqual(model.parseMonitors("[]", "eDP-1").error, "no-monitors")
assert.strictEqual(model.parseMonitors(fixture, "HDMI-A-9").error, "output-not-found")

const scales = ["1", "1.25", "1.6", "2", "3", "4"]
assert.strictEqual(model.scaleIndex(scales, 1.6), 2)
assert.strictEqual(model.scaleIndex(scales, 1.33), -1)
assert.strictEqual(model.validTextSize(16, [10, 12, 14, 16, 18, 20], 12), 16)
assert.strictEqual(model.validTextSize(15, [10, 12, 14, 16, 18, 20], 12), 12)

console.log("display model tests passed")
