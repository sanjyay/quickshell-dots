"use strict";

const assert = require("node:assert/strict");
const childProcess = require("node:child_process");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const test = require("node:test");
const helper = require("../scripts/holiday-helper.js");
const provider = require("../scripts/regional-holiday-provider.js");

const officialFile = path.join(__dirname, "../data/holidays/IN/TN/2026.json");

test("official Tamil Nadu 2026 source is valid, complete, and deterministic", () => {
  const source = JSON.parse(fs.readFileSync(officialFile, "utf8"));
  const value = provider.validateDataset(source, { country: "IN", subdivision: "TN", year: 2026 });
  assert.equal(value.source.publisher, "Government of Tamil Nadu");
  assert.equal(value.source.official, true);
  assert.match(value.source.gazette, /No[.] 721/);
  assert.equal(value.holidays.length, 23);
  assert.ok(value.holidays.length > 1);
  assert.deepEqual(value.holidays.map(row => row.date),
    [...value.holidays.map(row => row.date)].sort());
  assert.equal(new Set(value.holidays.map(row => `${row.date}\u001f${row.name.toLowerCase()}`)).size,
    value.holidays.length);
  for (const row of value.holidays) {
    assert.match(row.date, /^2026-\d{2}-\d{2}$/);
    assert.equal(row.type, "public");
    assert.equal(row.scope, "regional");
  }
  const expected = new Map([
    ["Pongal", "2026-01-15"],
    ["Thiruvalluvar Day", "2026-01-16"],
    ["Uzhavar Thirunal", "2026-01-17"],
    ["Tamil New Year's Day / Dr. B.R. Ambedkar's Birthday", "2026-04-14"],
    ["Vinayakar Chathurthi", "2026-09-14"],
    ["Ayutha Pooja", "2026-10-19"],
    ["Vijaya Dasami", "2026-10-20"],
    ["Deepavali", "2026-11-08"]
  ]);
  for (const [name, date] of expected)
    assert.ok(value.holidays.some(row => row.name === name && row.date === date), `${name} missing`);
  assert.ok(value.excluded.some(row => row.date === "2026-04-01" && /bank/i.test(row.reason)));
});

test("official provider wins for IN/TN/2026 and fallback remains available", () => {
  const official = provider.selectProvider("IN", "TN", 2026, { datasetVersion: "3.34.0" });
  assert.equal(official.kind, "official");
  assert.equal(official.id, "tn-government-2026");
  assert.equal(official.records.length, 23);
  const recurring = provider.selectProvider("IN", "TN", 2027, { datasetVersion: "3.34.0" });
  assert.equal(recurring.kind, "date-holidays+recurring-fallback");
  assert.equal(recurring.id, "tn-recurring-fixed");
  assert.deepEqual(recurring.records.map(row => [row.date, row.name]),
    [["2027-01-01", "New Year's Day"]]);

  const emptyRoot = fs.mkdtempSync(path.join(os.tmpdir(), "astra-regional-empty."));
  assert.equal(provider.selectProvider("IN", "MH", 2026, {
    datasetVersion: "3.34.0", dataRoot: emptyRoot
  }).kind, "date-holidays");
  assert.equal(provider.selectProvider("JP", "", 2026, {
    datasetVersion: "3.34.0", dataRoot: emptyRoot
  }).kind, "date-holidays");
  assert.equal(provider.selectProvider("IN", "TN", 2027, {
    datasetVersion: "3.34.0", dataRoot: emptyRoot
  }).kind, "date-holidays");
  fs.rmSync(emptyRoot, { recursive: true, force: true });
});

test("invalid official JSON fails safely and importer rejects invalid data", () => {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), "astra-regional-invalid."));
  const directory = path.join(root, "IN", "TN");
  fs.mkdirSync(directory, { recursive: true });
  fs.writeFileSync(path.join(directory, "2026.json"), "{broken");
  assert.throws(() => provider.loadOfficial("IN", "TN", 2026, { dataRoot: root }),
    error => error.code === "invalid-regional-json");

  const badInput = path.join(root, "bad.json");
  fs.writeFileSync(badInput, JSON.stringify({ schemaVersion: 1 }));
  const result = childProcess.spawnSync(process.execPath, [
    path.join(__dirname, "../scripts/import-regional-holidays.js"),
    "--country", "IN", "--subdivision", "TN", "--year", "2026", "--input", badInput
  ], { encoding: "utf8" });
  assert.notEqual(result.status, 0);
  assert.match(result.stderr, /regional dataset metadata is invalid/);
  fs.rmSync(root, { recursive: true, force: true });
});

test("official merge preserves national scope and exposes full regional months", () => {
  const temporary = fs.mkdtempSync(path.join(os.tmpdir(), "astra-regional-merge."));
  const value = helper.getHolidays({
    country: "IN", subdivision: "TN", year: 2026,
    showNational: true, showRegional: true,
    env: { HOME: temporary, XDG_CACHE_HOME: path.join(temporary, "cache") }
  });
  assert.equal(value.provider.kind, "official");
  assert.equal(value.provider.id, "tn-government-2026");
  assert.equal(value.holidays.find(row => row.name === "Republic Day").scope, "national");
  assert.ok(value.holidays.some(row => row.name === "Pongal" && row.scope === "regional"));
  assert.ok(value.holidays.some(row => row.name === "May Day" && row.scope === "regional"));
  assert.ok(value.holidays.some(row => row.name === "Deepavali" && row.scope === "regional"));
  assert.equal(value.holidays.some(row => row.date.startsWith("2026-07") && row.scope === "regional"), false);
  assert.equal(value.holidays.filter(row => row.date === "2026-10-02").length, 1);

  const national = helper.getHolidays({
    country: "IN", subdivision: "TN", year: 2026,
    showNational: true, showRegional: false,
    env: { HOME: temporary, XDG_CACHE_HOME: path.join(temporary, "cache") }
  });
  assert.ok(national.holidays.every(row => row.scope === "national"));
  const regional = helper.getHolidays({
    country: "IN", subdivision: "TN", year: 2026,
    showNational: false, showRegional: true,
    env: { HOME: temporary, XDG_CACHE_HOME: path.join(temporary, "cache") }
  });
  assert.ok(regional.holidays.length > 1);
  assert.ok(regional.holidays.every(row => row.scope === "regional"));
  const countryOnly = helper.getHolidays({
    country: "IN", year: 2026, showNational: true, showRegional: true,
    env: { HOME: temporary, XDG_CACHE_HOME: path.join(temporary, "cache") }
  });
  assert.equal(countryOnly.holidays.some(row => row.source === "tn-government-2026"), false);
  fs.rmSync(temporary, { recursive: true, force: true });
});

test("2027 fallback marks fixed New Year without claiming a complete annual source", () => {
  const temporary = fs.mkdtempSync(path.join(os.tmpdir(), "astra-regional-2027."));
  const value = helper.getHolidays({
    country: "IN", subdivision: "TN", year: 2027,
    showNational: true, showRegional: true,
    env: { HOME: temporary, XDG_CACHE_HOME: path.join(temporary, "cache") }
  });
  assert.equal(value.provider.kind, "date-holidays+recurring-fallback");
  assert.equal(value.provider.id, "tn-recurring-fixed");
  const newYear = value.holidays.find(row =>
    row.date === "2027-01-01" && row.name === "New Year's Day");
  assert.equal(newYear.scope, "regional");
  assert.equal(newYear.subdivisionCode, "TN");
  assert.equal(newYear.source, "tn-recurring-fixed");
  assert.ok(value.holidays.some(row =>
    row.date === "2027-01-26" && row.name === "Republic Day" && row.scope === "national"));
  fs.rmSync(temporary, { recursive: true, force: true });
});
