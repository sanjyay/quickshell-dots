"use strict";

const assert = require("node:assert/strict");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const childProcess = require("node:child_process");
const test = require("node:test");
const helper = require("../scripts/holiday-helper.js");

function table(entries) {
  return helper.parseZoneTable(entries.join("\n"));
}

test("zone table parsing handles unique, ambiguous, comments, and malformed rows", () => {
  const parsed = table([
    "# comment",
    "IN\t+2232+08822\tAsia/Kolkata",
    "JP\t+353916+1394441\tAsia/Tokyo",
    "US,CA\t+0000+00000\tAmerica/Shared",
    "malformed"
  ]);
  assert.deepEqual(parsed.get("Asia/Kolkata"), ["IN"]);
  assert.deepEqual(parsed.get("Asia/Tokyo"), ["JP"]);
  assert.deepEqual(parsed.get("America/Shared"), ["CA", "US"]);
  assert.equal(parsed.has("undefined"), false);
});

test("unique timezone detection and configured override are deterministic", () => {
  const zones = table(["IN\t+0000+00000\tAsia/Kolkata", "JP\t+0000+00000\tAsia/Tokyo"]);
  assert.equal(helper.resolveCountry({ timezone: "Asia/Kolkata", table: zones }).country, "IN");
  assert.equal(helper.resolveCountry({ timezone: "Asia/Tokyo", table: zones }).country, "JP");
  const override = helper.resolveCountry({ override: "US", timezone: "Asia/Kolkata", table: zones });
  assert.equal(override.country, "US");
  assert.equal(override.source, "override");
});

test("legacy timezone aliases are canonicalized where the runtime supports them", () => {
  const canonical = helper.canonicalTimezone("US/Eastern");
  assert.ok(canonical === "America/New_York" || canonical === "US/Eastern");
  const zones = table(["US\t+404251-0740023\tAmerica/New_York", "US\t+404251-0740023\tUS/Eastern"]);
  assert.equal(helper.resolveCountry({ timezone: "US/Eastern", table: zones }).country, "US");
});

test("ambiguous timezone needs a matching locale or a manual selection", () => {
  const zones = table(["US,CA\t+0000+00000\tAmerica/Shared"]);
  const ambiguous = helper.resolveCountry({ timezone: "America/Shared", table: zones, env: { LANG: "C" } });
  assert.equal(ambiguous.status, "ambiguous");
  assert.equal(ambiguous.country, null);
  assert.deepEqual(ambiguous.candidates, ["CA", "US"]);
  assert.equal(helper.resolveCountry({
    timezone: "America/Shared", table: zones, env: { LANG: "en_CA.UTF-8" }
  }).country, "CA");
  assert.equal(helper.resolveCountry({
    timezone: "America/Shared", table: zones, territory: "US"
  }).country, "US");
});

test("unknown and fixed-offset timezones fail in a controlled way", () => {
  const zones = table(["IN\t+0000+00000\tAsia/Kolkata"]);
  assert.equal(helper.resolveCountry({ timezone: "Etc/GMT-5", table: zones }).status, "unresolved");
  assert.throws(() => helper.resolveCountry({
    timezone: "UTC+05:30", table: zones, env: {},
    readFile() { throw new Error("missing"); },
    readlink() { throw new Error("missing"); },
    exec() { throw new Error("missing"); }
  }), error => error.code === "timezone-unavailable");
  assert.throws(() => helper.detectTimezone({ env: { TZ: "UTC+05:30" } }),
    error => error.code === "timezone-fixed-offset");
  assert.equal(helper.detectTimezone({ env: { TZ: ":/usr/share/zoneinfo/Asia/Kolkata" } }), "Asia/Kolkata");
});

test("holiday rows filter, deduplicate, retain distinct same-day holidays, and sort", () => {
  const rows = helper.normalizeHolidayRows([
    { date: "2026-02-01 00:00:00", name: "Zulu", type: "public" },
    { date: "2026-01-01 00:00:00", name: "Alpha", type: "public" },
    { date: "2026-01-01 00:00:00", name: "Beta", type: "public" },
    { date: "2026-01-01 00:00:00", name: "Alpha", type: "public" },
    { date: "2026-01-02 00:00:00", name: "Observance", type: "observance" }
  ], ["public"]);
  assert.deepEqual(rows, [
    { date: "2026-01-01", name: "Alpha", type: "public", substitute: false },
    { date: "2026-01-01", name: "Beta", type: "public", substitute: false },
    { date: "2026-02-01", name: "Zulu", type: "public", substitute: false }
  ]);
});

test("country metadata is dataset-derived, valid, and deterministically sorted", () => {
  const values = helper.countries();
  assert.ok(values.length > 100);
  assert.ok(values.some(item => item.code === "IN" && item.name === "India"));
  assert.ok(values.some(item => item.code === "JP" && item.name.length > 0));
  assert.ok(values.every(item => /^[A-Z]{2}$/.test(item.code) && item.name.trim()));
  assert.deepEqual(values, [...values].sort((a, b) =>
    a.name.localeCompare(b.name, "en") || a.code.localeCompare(b.code)));
});

test("subdivision metadata includes Tamil Nadu and permits valid empty lists", () => {
  const india = helper.subdivisions("IN");
  assert.ok(india.some(item => item.code === "TN" && item.name === "Tamil Nadu"));
  assert.deepEqual(india, [...india].sort((a, b) =>
    a.name.localeCompare(b.name, "en") || a.code.localeCompare(b.code)));
  assert.deepEqual(helper.subdivisions("JP"), []);
  assert.throws(() => helper.subdivisions("ZZ"), error => error.code === "unsupported-country");
});

test("classification keeps national, regional, duplicates, and same-day identities correct", () => {
  const national = [
    { date: "2026-01-01 00:00:00", name: "National Day", type: "public" }
  ];
  const regional = [
    ...national,
    { date: "2026-01-01 00:00:00", name: "Regional Day", type: "public" },
    { date: "2026-01-01 00:00:00", name: "Regional Day", type: "public" }
  ];
  const rows = helper.classifyHolidays("IN", "TN", 2026, {
    factory: (country, subdivision) => ({ getHolidays: () => subdivision ? regional : national })
  });
  assert.equal(rows.filter(item => item.name === "National Day").length, 1);
  assert.equal(rows.find(item => item.name === "National Day").scope, "national");
  assert.equal(rows.find(item => item.name === "Regional Day").scope, "regional");
  assert.equal(rows.filter(item => item.date === "2026-01-01").length, 2);
});

test("real India and Tamil Nadu scope classification is stable for 2026", () => {
  const rows = helper.classifyHolidays("IN", "TN", 2026);
  const republic = rows.find(item => item.date === "2026-01-26" && item.name === "Republic Day");
  const labour = rows.find(item => item.date === "2026-05-01" && item.name === "Labour Day");
  assert.equal(republic.scope, "national");
  assert.equal(republic.subdivisionCode, null);
  assert.equal(labour.scope, "regional");
  assert.equal(labour.subdivisionCode, "TN");
  assert.equal(labour.subdivisionName, "Tamil Nadu");
});

test("national and regional filters are independent", () => {
  const temporary = fs.mkdtempSync(path.join(os.tmpdir(), "astra-holiday-filter."));
  const env = { HOME: temporary, XDG_CACHE_HOME: path.join(temporary, "cache") };
  const national = helper.getHolidays({
    country: "IN", subdivision: "TN", year: 2026, showNational: true,
    showRegional: false, env
  });
  assert.ok(national.holidays.length > 0);
  assert.ok(national.holidays.every(item => item.scope === "national"));
  const regional = helper.getHolidays({
    country: "IN", subdivision: "TN", year: 2026, showNational: false,
    showRegional: true, env
  });
  assert.ok(regional.holidays.some(item => item.name === "Pongal"));
  assert.ok(regional.holidays.some(item => item.name === "May Day"));
  assert.ok(regional.holidays.every(item => item.scope === "regional"));
  const none = helper.getHolidays({
    country: "JP", year: 2026, showNational: false, showRegional: false, env
  });
  assert.deepEqual(none.holidays, []);
  fs.rmSync(temporary, { recursive: true, force: true });
});

test("generation validates inputs and contains stable India and Japan dates", () => {
  assert.throws(() => helper.generate("ZZ", "", 2026, ["public"]),
    error => error.code === "unsupported-country");
  assert.throws(() => helper.generate("IN", "INVALID", 2026, ["public"]),
    error => error.code === "unsupported-subdivision");
  const india = helper.generate("IN", "", 2026, ["public"]);
  assert.ok(india.holidays.some(item => item.date === "2026-01-26" && item.name === "Republic Day"));
  assert.ok(india.holidays.every(item => /^\d{4}-\d{2}-\d{2}$/.test(item.date) && item.type === "public"));
  const japan = helper.generate("JP", "", 2026, ["public"]);
  assert.ok(japan.holidays.some(item => item.date === "2026-01-01"));
  assert.deepEqual(india.holidays, [...india.holidays].sort((a, b) =>
    a.date.localeCompare(b.date) || a.name.localeCompare(b.name) || a.type.localeCompare(b.type)));
});

test("subdivision is passed to the date-holidays factory", () => {
  let received = null;
  helper.generate("IN", "TN", 2026, ["public"], (country, subdivision) => {
    received = [country, subdivision];
    return { getHolidays: () => [] };
  });
  assert.deepEqual(received, ["IN", "TN"]);
});

test("cache keys separate country, subdivision, year, public scopes, and providers", () => {
  const base = helper.cacheKey("IN", "", 2026, "national");
  assert.notEqual(base, helper.cacheKey("JP", "", 2026, "national"));
  assert.notEqual(base, helper.cacheKey("IN", "TN", 2026, "national"));
  assert.notEqual(base, helper.cacheKey("IN", "", 2027, "national"));
  assert.notEqual(base, helper.cacheKey("IN", "", 2026, "regional"));
  assert.notEqual(
    helper.cacheKey("IN", "TN", 2026, "national+regional", "tn-government-2026-schema1-revision1"),
    helper.cacheKey("IN", "TN", 2026, "national+regional", "date-holidays-3.34.0")
  );
});

test("metadata cache loads and corrupt metadata regenerates atomically", () => {
  const temporary = fs.mkdtempSync(path.join(os.tmpdir(), "astra-holiday-meta."));
  const env = { HOME: temporary, XDG_CACHE_HOME: path.join(temporary, "cache") };
  let calls = 0;
  const first = helper.cachedMetadata("countries", "", () => { calls++; return [{ code: "IN", name: "India" }]; }, env);
  assert.equal(first.cached, false);
  const second = helper.cachedMetadata("countries", "", () => { calls++; return []; }, env);
  assert.equal(second.cached, true);
  assert.equal(calls, 1);
  fs.writeFileSync(first.cachePath, "{broken");
  const recovered = helper.cachedMetadata("countries", "", () => { calls++; return [{ code: "JP", name: "Japan" }]; }, env);
  assert.equal(recovered.cached, false);
  assert.equal(calls, 2);
  assert.equal(fs.readdirSync(path.dirname(first.cachePath)).some(name => name.startsWith(".")), false);
  fs.rmSync(temporary, { recursive: true, force: true });
});

test("valid cache loads, corrupt cache regenerates, and writes are atomic", () => {
  const temporary = fs.mkdtempSync(path.join(os.tmpdir(), "astra-holiday-test."));
  const env = { HOME: temporary, XDG_CACHE_HOME: path.join(temporary, "cache") };
  let calls = 0;
  const factory = () => ({
    getHolidays: () => {
      calls++;
      return [{ date: "2026-01-26 00:00:00", name: "Republic Day", type: "public" }];
    }
  });
  const first = helper.getHolidays({ country: "IN", year: 2026, types: ["public"], env, factory });
  assert.equal(first.cached, false);
  assert.equal(calls, 1);
  const second = helper.getHolidays({ country: "IN", year: 2026, types: ["public"], env, factory });
  assert.equal(second.cached, true);
  assert.equal(calls, 1);
  fs.writeFileSync(first.cachePath, "{broken");
  const recovered = helper.getHolidays({ country: "IN", year: 2026, types: ["public"], env, factory });
  assert.equal(recovered.cached, false);
  assert.equal(calls, 2);
  assert.equal(fs.readdirSync(path.dirname(first.cachePath)).some(name => name.startsWith(".")), false);
  fs.rmSync(temporary, { recursive: true, force: true });
});

test("old incomplete cache schemas and provider-less keys are regenerated", () => {
  const temporary = fs.mkdtempSync(path.join(os.tmpdir(), "astra-holiday-old-cache."));
  const env = { HOME: temporary, XDG_CACHE_HOME: path.join(temporary, "cache") };
  const file = helper.cachePath("IN", "TN", 2026, "national+regional", env,
    "tn-government-2026-schema1-revision1");
  fs.mkdirSync(path.dirname(file), { recursive: true });
  fs.writeFileSync(file, JSON.stringify({
    schemaVersion: 4,
    datasetVersion: "3.34.0",
    country: "IN",
    subdivision: "TN",
    year: 2026,
    categoryKey: "national+regional+bank",
    holidays: []
  }));
  const value = helper.getHolidays({
    country: "IN", subdivision: "TN", year: 2026,
    showNational: true, showRegional: true, env
  });
  assert.equal(value.cached, false);
  assert.equal(value.schemaVersion, 5);
  assert.equal(value.categoryKey, "national+regional");
  assert.equal(value.provider.id, "tn-government-2026");
  assert.ok(value.holidays.some(item => item.name === "Pongal" && item.scope === "regional"));
  fs.rmSync(temporary, { recursive: true, force: true });
});

test("the runtime helper contains no network client", () => {
  const source = [
    "../scripts/holiday-helper.js",
    "../scripts/regional-holiday-provider.js",
    "../scripts/import-regional-holidays.js"
  ].map(file => fs.readFileSync(path.join(__dirname, file), "utf8")).join("\n");
  assert.doesNotMatch(source, /\b(fetch|https?\.request|curl|wget)\b/);
});

test("invalid helper commands and selections return structured errors", () => {
  const script = path.join(__dirname, "../scripts/holiday-helper.js");
  for (const args of [["unknown"], ["subdivisions", "ZZ"], ["holidays", "IN", "bad-year"]]) {
    const result = childProcess.spawnSync(process.execPath, [script, ...args], { encoding: "utf8" });
    assert.notEqual(result.status, 0);
    const payload = JSON.parse(result.stdout);
    assert.equal(payload.ok, false);
    assert.ok(payload.error.code);
    assert.ok(result.stderr.startsWith("holiday-helper:"));
  }
});

test("holiday settings state writes are private, atomic, and path restricted", () => {
  const temporary = fs.mkdtempSync(path.join(os.tmpdir(), "astra-holiday-state."));
  const env = { ...process.env, HOME: temporary, XDG_STATE_HOME: path.join(temporary, "state") };
  const target = path.join(env.XDG_STATE_HOME, "quickshell-astra", "holiday-settings.json");
  const script = path.join(__dirname, "../scripts/holiday-helper.js");
  const data = JSON.stringify({ schemaVersion: 1, countryMode: "manual", country: "IN" });
  const result = childProcess.spawnSync(process.execPath,
    [script, "state-write", "--json", target],
    { encoding: "utf8", env, input: JSON.stringify({ data }) + "\n" });
  assert.equal(result.status, 0, result.stderr);
  assert.equal(fs.readFileSync(target, "utf8"), data);
  assert.equal(fs.statSync(target).mode & 0o777, 0o600);
  assert.equal(fs.readdirSync(path.dirname(target)).some(name => name.startsWith(".")), false);
  const rejected = childProcess.spawnSync(process.execPath,
    [script, "state-write", "--json", path.join(temporary, "elsewhere.json")],
    { encoding: "utf8", env, input: JSON.stringify({ data }) + "\n" });
  assert.notEqual(rejected.status, 0);
  assert.equal(JSON.parse(rejected.stdout).error.code, "invalid-state-path");
  fs.rmSync(temporary, { recursive: true, force: true });
});
