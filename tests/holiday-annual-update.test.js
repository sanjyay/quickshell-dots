"use strict";

const assert = require("node:assert/strict");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const test = require("node:test");
const updater = require("../scripts/holiday-annual-update.js");
const provider = require("../scripts/regional-holiday-provider.js");

function fixture() {
  return path.join(__dirname, "../data/holidays/IN/TN/2026.json");
}

test("annual update validates and atomically installs a verified official file", async () => {
  const temporary = fs.mkdtempSync(path.join(os.tmpdir(), "astra-holiday-annual."));
  const env = {
    HOME: temporary,
    XDG_DATA_HOME: path.join(temporary, "data"),
    XDG_CACHE_HOME: path.join(temporary, "cache"),
    XDG_STATE_HOME: path.join(temporary, "state")
  };
  const cache = path.join(env.XDG_CACHE_HOME, "quickshell-astra", "holidays");
  fs.mkdirSync(cache, { recursive: true });
  fs.writeFileSync(path.join(cache, "IN_TN_2026_old.json"), "{}");
  fs.writeFileSync(path.join(cache, "IN_TN_2027_keep.json"), "{}");
  const result = await updater.update({
    year: 2026,
    country: "IN",
    subdivision: "TN",
    input: fixture(),
    env,
    now: new Date("2026-01-01T09:00:00Z")
  });
  assert.equal(result.status, "updated");
  assert.equal(result.providerId, "tn-government-2026");
  assert.equal(result.holidays, 23);
  assert.equal(result.cachesRemoved, 1);
  assert.equal(fs.statSync(result.target).mode & 0o777, 0o600);
  assert.equal(fs.existsSync(path.join(cache, "IN_TN_2026_old.json")), false);
  assert.equal(fs.existsSync(path.join(cache, "IN_TN_2027_keep.json")), true);
  assert.equal(fs.readdirSync(path.dirname(result.target)).some(name => name.startsWith(".")), false);
  const loaded = provider.loadOfficial("IN", "TN", 2026, { env });
  assert.equal(loaded.file, result.target);
  assert.equal(loaded.records.length, 23);
  fs.rmSync(temporary, { recursive: true, force: true });
});

test("invalid annual data cannot replace an existing verified file", async () => {
  const temporary = fs.mkdtempSync(path.join(os.tmpdir(), "astra-holiday-invalid-annual."));
  const env = { HOME: temporary, XDG_DATA_HOME: path.join(temporary, "data") };
  const target = provider.datasetPath("IN", "TN", 2026, provider.userDataRoot(env));
  fs.mkdirSync(path.dirname(target), { recursive: true });
  fs.writeFileSync(target, "{\"existing\":true}\n");
  const invalid = path.join(temporary, "invalid.json");
  fs.writeFileSync(invalid, JSON.stringify({
    schemaVersion: 1, revision: 1, countryCode: "IN", subdivisionCode: "TN",
    year: 2026, providerId: "bad", source: { official: false }, holidays: []
  }));
  await assert.rejects(updater.update({
    year: 2026, country: "IN", subdivision: "TN", input: invalid, env
  }), /source metadata is invalid/);
  assert.equal(fs.readFileSync(target, "utf8"), "{\"existing\":true}\n");
  fs.rmSync(temporary, { recursive: true, force: true });
});

test("an unavailable annual release preserves existing verified data", async () => {
  const temporary = fs.mkdtempSync(path.join(os.tmpdir(), "astra-holiday-unpublished."));
  const env = { HOME: temporary, XDG_DATA_HOME: path.join(temporary, "data") };
  const target = provider.datasetPath("IN", "TN", 2027, provider.userDataRoot(env));
  fs.mkdirSync(path.dirname(target), { recursive: true });
  fs.writeFileSync(target, "{\"existing\":true}\n");
  const unavailable = new Error("no verified annual holiday file is published yet");
  unavailable.code = "not-published";
  await assert.rejects(updater.update({
    year: 2027,
    country: "IN",
    subdivision: "TN",
    env,
    fetchText: async () => { throw unavailable; }
  }), error => error.code === "not-published");
  assert.equal(fs.readFileSync(target, "utf8"), "{\"existing\":true}\n");
  fs.rmSync(temporary, { recursive: true, force: true });
});

test("network annual sources must use HTTPS", async () => {
  await assert.rejects(updater.update({
    year: 2027,
    country: "IN",
    subdivision: "TN",
    sourceUrl: "http://example.test/{year}.json",
    fetchText: async () => { throw new Error("must not be reached"); }
  }), /must use HTTPS/);
});

test("annual timer is January-first, persistent, and narrowly scoped", () => {
  const timer = fs.readFileSync(path.join(__dirname,
    "../systemd/quickshell-astra-holiday-annual-update.timer"), "utf8");
  const service = fs.readFileSync(path.join(__dirname,
    "../systemd/quickshell-astra-holiday-annual-update.service"), "utf8");
  assert.match(timer, /OnCalendar=\*-01-01 09:00:00/);
  assert.match(timer, /Persistent=true/);
  assert.match(timer, /RandomizedDelaySec=30min/);
  assert.match(service, /holiday-annual-update[.]js/);
  assert.doesNotMatch(service, /sh -c|bash -c/);
});
