#!/usr/bin/env node
"use strict";

const fs = require("fs");
const os = require("os");
const path = require("path");
const childProcess = require("child_process");
const Holidays = require("date-holidays");
const dataset = require("date-holidays/package.json");
const regionalProvider = require("./regional-holiday-provider.js");

const SCHEMA_VERSION = 5;
const PROJECT = "quickshell-astra";
const VALID_TYPES = new Set(["public"]);
const holidayCatalog = new Holidays();

class HelperError extends Error {
  constructor(code, message, details = {}) {
    super(message);
    this.code = code;
    this.details = details;
  }
}

function fail(code, message, details) {
  throw new HelperError(code, message, details);
}

function normalizeCountry(value) {
  const country = String(value || "").trim().toUpperCase();
  if (!/^[A-Z]{2}$/.test(country)) fail("invalid-country", "country must be 'auto' or an ISO alpha-2 code");
  return country;
}

function normalizeSubdivision(value) {
  const subdivision = String(value || "").trim().toUpperCase();
  if (subdivision && !/^[A-Z0-9-]{1,12}$/.test(subdivision))
    fail("invalid-subdivision", "subdivision contains unsupported characters");
  return subdivision;
}

function normalizeYear(value) {
  const year = Number(value);
  if (!Number.isInteger(year) || year < 1900 || year > 2200)
    fail("invalid-year", "year must be an integer between 1900 and 2200");
  return year;
}

function normalizeTypes(value) {
  const values = Array.isArray(value) ? value : String(value || "public").split(",");
  const types = [...new Set(values.map(item => String(item).trim().toLowerCase()).filter(Boolean))].sort();
  if (!types.length || types.some(type => !VALID_TYPES.has(type)))
    fail("invalid-types", "only public holiday records are supported");
  return types;
}

function normalizeBoolean(value, fallback) {
  if (value === undefined || value === null || value === "") return fallback;
  if (value === true || value === "true" || value === "1") return true;
  if (value === false || value === "false" || value === "0") return false;
  fail("invalid-boolean", `invalid boolean value: ${value}`);
}

function validIanaZone(value) {
  let timezone = String(value || "").trim().replace(/^:/, "");
  const marker = "/usr/share/zoneinfo/";
  const markerOffset = timezone.indexOf(marker);
  if (markerOffset >= 0) timezone = timezone.substring(markerOffset + marker.length);
  return /^[A-Za-z][A-Za-z0-9._+-]*(?:\/[A-Za-z0-9._+-]+)+$/.test(timezone) ? timezone : "";
}

function canonicalTimezone(value) {
  const timezone = validIanaZone(value);
  if (!timezone) return "";
  try {
    return new Intl.DateTimeFormat("en", { timeZone: timezone }).resolvedOptions().timeZone || timezone;
  } catch (_) {
    return timezone;
  }
}

function detectTimezone(options = {}) {
  const env = options.env || process.env;
  const readFile = options.readFile || (file => fs.readFileSync(file, "utf8"));
  const readlink = options.readlink || (file => fs.realpathSync(file));
  const exec = options.exec || (() => childProcess.execFileSync(
    "timedatectl", ["show", "--property=Timezone", "--value"],
    { encoding: "utf8", stdio: ["ignore", "pipe", "ignore"], timeout: 1500 }
  ));
  const candidates = [];
  if (env.TZ) {
    const timezone = validIanaZone(env.TZ);
    if (timezone) return timezone;
    fail("timezone-fixed-offset", "TZ is set but is not a mappable IANA timezone");
  }
  try { candidates.push(readFile("/etc/timezone")); } catch (_) {}
  try { candidates.push(exec()); } catch (_) {}
  try {
    const target = readlink("/etc/localtime");
    const marker = "/usr/share/zoneinfo/";
    const offset = target.indexOf(marker);
    if (offset >= 0) candidates.push(target.substring(offset + marker.length));
  } catch (_) {}
  for (const candidate of candidates) {
    const timezone = validIanaZone(candidate);
    if (timezone) return timezone;
  }
  fail("timezone-unavailable", "no valid IANA timezone could be detected");
}

function parseZoneTable(text) {
  const result = new Map();
  for (const raw of String(text || "").split(/\r?\n/)) {
    const line = raw.trim();
    if (!line || line.startsWith("#")) continue;
    const fields = line.split(/\s+/);
    if (fields.length < 3 || !validIanaZone(fields[2])) continue;
    const countries = fields[0].split(",").map(code => code.toUpperCase()).filter(code => /^[A-Z]{2}$/.test(code));
    if (!countries.length) continue;
    const existing = result.get(fields[2]) || [];
    result.set(fields[2], [...new Set(existing.concat(countries))].sort());
  }
  return result;
}

function localeTerritory(env = process.env) {
  for (const key of ["LC_ALL", "LC_MESSAGES", "LANG"]) {
    const match = String(env[key] || "").match(/[_-]([A-Za-z]{2})(?:[.@]|$)/);
    if (match) return match[1].toUpperCase();
  }
  return "";
}

function loadZoneTable(options = {}) {
  const readFile = options.readFile || (file => fs.readFileSync(file, "utf8"));
  for (const file of options.zoneFiles || ["/usr/share/zoneinfo/zone1970.tab", "/usr/share/zoneinfo/zone.tab"]) {
    try { return { table: parseZoneTable(readFile(file)), source: file }; } catch (_) {}
  }
  fail("zone-table-unavailable", "zone1970.tab and zone.tab are unavailable");
}

function resolveCountry(options = {}) {
  if (options.override && String(options.override).toLowerCase() !== "auto")
    return { status: "ok", country: normalizeCountry(options.override), timezone: options.timezone || null, source: "override" };
  const detected = validIanaZone(options.timezone) || detectTimezone(options);
  const canonical = canonicalTimezone(detected);
  const timezone = detected;
  const loaded = options.table ? { table: options.table, source: options.tableSource || "provided" } : loadZoneTable(options);
  const countries = loaded.table.get(detected) || loaded.table.get(canonical) || [];
  if (!countries.length)
    return { status: "unresolved", country: null, timezone, source: loaded.source, reason: "timezone-not-mapped" };
  if (countries.length === 1)
    return { status: "ok", country: countries[0], timezone, source: "timezone" };
  const territory = String(options.territory || localeTerritory(options.env)).toUpperCase();
  if (territory && countries.includes(territory))
    return { status: "ok", country: territory, timezone, source: "locale", candidates: countries };
  return { status: "ambiguous", country: null, timezone, source: loaded.source, candidates: countries,
    reason: "select-country" };
}

function validateSupport(country, subdivision) {
  const countries = holidayCatalog.getCountries();
  if (!countries[country]) fail("unsupported-country", `date-holidays does not support ${country}`, { country });
  if (subdivision) {
    const states = holidayCatalog.getStates(country) || {};
    if (!states[subdivision])
      fail("unsupported-subdivision", `date-holidays does not support ${country}-${subdivision}`,
        { country, subdivision });
  }
}

function normalizeHolidayRows(rows, types) {
  const wanted = new Set(types);
  const seen = new Set();
  const output = [];
  for (const row of rows || []) {
    const date = String(row.date || "").slice(0, 10);
    const name = String(row.name || "").trim();
    const type = String(row.type || "").trim().toLowerCase();
    if (!/^\d{4}-\d{2}-\d{2}$/.test(date) || !name || !wanted.has(type)) continue;
    const substitute = row.substitute === true;
    const key = `${date}\u001f${name}\u001f${type}\u001f${substitute ? "1" : "0"}`;
    if (seen.has(key)) continue;
    seen.add(key);
    output.push({ date, name, type, substitute });
  }
  output.sort((a, b) => a.date.localeCompare(b.date) || a.name.localeCompare(b.name) || a.type.localeCompare(b.type));
  return output;
}

function countries() {
  const output = Object.entries(holidayCatalog.getCountries())
    .filter(([code, name]) => /^[A-Z]{2}$/.test(code) && String(name || "").trim())
    .map(([code, name]) => ({ code, name: String(name).trim() }));
  output.sort((a, b) => a.name.localeCompare(b.name, "en") || a.code.localeCompare(b.code));
  return output;
}

function subdivisions(countryValue) {
  const country = normalizeCountry(countryValue);
  validateSupport(country, "");
  const values = holidayCatalog.getStates(country) || {};
  const output = Object.entries(values)
    .filter(([code, name]) => /^[A-Z0-9-]{1,12}$/.test(code) && String(name || "").trim())
    .map(([code, name]) => ({ code, name: String(name).trim() }));
  output.sort((a, b) => a.name.localeCompare(b.name, "en") || a.code.localeCompare(b.code));
  return output;
}

function holidayIdentity(row) {
  return [
    String(row.date || "").slice(0, 10),
    String(row.name || "").trim().toLocaleLowerCase("en"),
    String(row.type || "").trim().toLowerCase(),
    row.substitute === true ? "1" : "0"
  ].join("\u001f");
}

function officialComparisonIdentity(row) {
  const normalizedName = String(row.name || "").normalize("NFKD")
    .replace(/[\u0300-\u036f]/g, "")
    .toLocaleLowerCase("en")
    .replace(/\bjayanthi\b/g, "jayanti")
    .replace(/[^a-z0-9]+/g, " ")
    .replace(/\bday$/g, "")
    .trim();
  return `${String(row.date || "").slice(0, 10)}\u001f${normalizedName}`;
}

function classifyHolidays(country, subdivision, year, options = {}) {
  validateSupport(country, subdivision);
  const factory = options.factory || ((...args) => new Holidays(...args));
  const nationalRows = normalizeHolidayRows(factory(country).getHolidays(year), ["public"]);
  const regionalRows = subdivision
    ? normalizeHolidayRows(factory(country, subdivision).getHolidays(year), ["public"])
    : nationalRows;
  const nationalPublic = new Set(nationalRows.map(holidayIdentity));
  const combined = subdivision ? nationalRows.concat(regionalRows) : nationalRows;
  const seen = new Set();
  const output = [];
  const countryName = String(holidayCatalog.getCountries()[country] || country);
  const subdivisionName = subdivision
    ? String((holidayCatalog.getStates(country) || {})[subdivision] || subdivision)
    : null;
  for (const row of combined) {
    const identity = holidayIdentity(row);
    const scope = nationalPublic.has(identity) ? "national" : "regional";
    const dedupeKey = `${identity}\u001f${scope}`;
    if (seen.has(dedupeKey)) continue;
    seen.add(dedupeKey);
    output.push({
      date: row.date,
      name: row.name,
      type: row.type,
      scope,
      substitute: row.substitute === true,
      countryCode: country,
      countryName,
      subdivisionCode: scope === "regional" ? subdivision : null,
      subdivisionName: scope === "regional" ? subdivisionName : null,
      source: "date-holidays"
    });
  }
  output.sort((a, b) => a.date.localeCompare(b.date) || a.name.localeCompare(b.name) ||
    a.scope.localeCompare(b.scope) || a.type.localeCompare(b.type));
  return output;
}

function cacheHome(env = process.env) {
  return env.XDG_CACHE_HOME || path.join(env.HOME || os.homedir(), ".cache");
}

function categoryKey(showNational, showRegional) {
  const enabled = [];
  if (showNational) enabled.push("national");
  if (showRegional) enabled.push("regional");
  return enabled.length ? enabled.join("+") : "none";
}

function cacheKey(country, subdivision, year, typesOrCategories, providerFingerprint = `date-holidays-${dataset.version}`) {
  const categories = Array.isArray(typesOrCategories) ? typesOrCategories.join("+") : String(typesOrCategories);
  const provider = String(providerFingerprint).replace(/[^A-Za-z0-9._+-]/g, "-");
  return [country, subdivision || "national", year, categories, provider].join("_");
}

function cachePath(country, subdivision, year, categories, env = process.env, providerFingerprint) {
  return path.join(cacheHome(env), PROJECT, "holidays",
    `${cacheKey(country, subdivision, year, categories, providerFingerprint)}.json`);
}

function metadataCachePath(kind, country, env = process.env) {
  const suffix = country ? `_${country}` : "";
  return path.join(cacheHome(env), PROJECT, "holidays",
    `${kind}${suffix}_date-holidays-${dataset.version}.json`);
}

function cachedMetadata(kind, country, producer, env = process.env) {
  const file = metadataCachePath(kind, country, env);
  try {
    const value = JSON.parse(fs.readFileSync(file, "utf8"));
    if (value && value.schemaVersion === SCHEMA_VERSION && value.datasetVersion === dataset.version &&
        value.kind === kind && (value.countryCode || "") === (country || "") && Array.isArray(value.items))
      return { items: value.items, cached: true, cachePath: file };
  } catch (_) {}
  const items = producer();
  writeJsonAtomic(file, {
    schemaVersion: SCHEMA_VERSION,
    datasetVersion: dataset.version,
    kind,
    countryCode: country || null,
    items
  });
  return { items, cached: false, cachePath: file };
}

function validPayload(value, expected) {
  return value && value.schemaVersion === SCHEMA_VERSION && value.datasetVersion === dataset.version &&
    value.country === expected.country && (value.subdivision || "") === (expected.subdivision || "") &&
    value.year === expected.year && value.categoryKey === expected.categoryKey &&
    value.providerFingerprint === expected.providerFingerprint &&
    Array.isArray(value.holidays) && value.holidays.every(item =>
      item && /^\d{4}-\d{2}-\d{2}$/.test(String(item.date || "")) &&
      String(item.name || "").trim() !== "" && ["national", "regional"].includes(item.scope) &&
      item.type === "public");
}

function readCache(file, expected) {
  try {
    const value = JSON.parse(fs.readFileSync(file, "utf8"));
    return validPayload(value, expected) ? value : null;
  } catch (_) {
    return null;
  }
}

function writeJsonAtomic(file, value) {
  fs.mkdirSync(path.dirname(file), { recursive: true, mode: 0o700 });
  const temp = path.join(path.dirname(file), `.${path.basename(file)}.${process.pid}.${Date.now()}`);
  try {
    fs.writeFileSync(temp, `${JSON.stringify(value)}\n`, { mode: 0o600 });
    fs.renameSync(temp, file);
  } finally {
    try { fs.unlinkSync(temp); } catch (_) {}
  }
}

function writeStateFromStdin(argv, env = process.env) {
  const validateJson = argv[0] === "--json";
  const file = path.resolve(validateJson ? argv[1] || "" : argv[0] || "");
  const expected = path.resolve(env.XDG_STATE_HOME || path.join(env.HOME || os.homedir(), ".local/state"),
    PROJECT, "holiday-settings.json");
  if (file !== expected) fail("invalid-state-path", "holiday settings may only be written to the project state path");
  let wrapper;
  try {
    const chunks = [];
    let total = 0;
    while (total < 65536) {
      const buffer = Buffer.alloc(Math.min(4096, 65536 - total));
      const bytes = fs.readSync(0, buffer, 0, buffer.length, null);
      if (!bytes) break;
      chunks.push(buffer.subarray(0, bytes));
      total += bytes;
      if (buffer.subarray(0, bytes).includes(0x0a)) break;
    }
    const line = Buffer.concat(chunks).toString("utf8").split(/\r?\n/, 1)[0];
    wrapper = JSON.parse(line);
  }
  catch (_) { fail("invalid-state-input", "state input must be JSON"); }
  if (!wrapper || typeof wrapper.data !== "string")
    fail("invalid-state-input", "state input must contain a string data field");
  if (validateJson) {
    try { JSON.parse(wrapper.data); }
    catch (_) { fail("invalid-state-json", "state data is not valid JSON"); }
  }
  fs.mkdirSync(path.dirname(file), { recursive: true, mode: 0o700 });
  const temp = path.join(path.dirname(file), `.${path.basename(file)}.${process.pid}.${Date.now()}`);
  try {
    fs.writeFileSync(temp, wrapper.data, { mode: 0o600 });
    fs.renameSync(temp, file);
  } finally {
    try { fs.unlinkSync(temp); } catch (_) {}
  }
  return { path: file };
}

function generate(country, subdivision, year, types, factory = (...args) => new Holidays(...args)) {
  validateSupport(country, subdivision);
  let instance;
  try { instance = factory(country, subdivision || undefined); }
  catch (error) { fail("dataset-initialization-failed", error.message, { country, subdivision }); }
  const holidays = normalizeHolidayRows(instance.getHolidays(year), types);
  return {
    schemaVersion: SCHEMA_VERSION,
    datasetVersion: dataset.version,
    country,
    countryName: String((holidayCatalog.getCountries()[country] || country)),
    subdivision: subdivision || null,
    year,
    types,
    holidays
  };
}

function mergeRegionalProvider(country, subdivision, base, selectedProvider) {
  const national = base.filter(row => row.scope === "national");
  const nationalIdentities = new Set(national.map(officialComparisonIdentity));
  const countryName = String(holidayCatalog.getCountries()[country] || country);
  const regional = selectedProvider.records.map(row => ({
    date: row.date,
    name: row.name,
    type: "public",
    scope: "regional",
    substitute: false,
    countryCode: country,
    countryName,
    subdivisionCode: subdivision,
    subdivisionName: row.subdivisionName,
    source: row.source
  })).filter(row => !nationalIdentities.has(officialComparisonIdentity(row)));
  const seen = new Set();
  const output = [];
  for (const row of base.concat(regional)) {
    const key = `${holidayIdentity(row)}\u001f${row.scope}`;
    if (seen.has(key)) continue;
    seen.add(key);
    output.push(row);
  }
  output.sort((a, b) => a.date.localeCompare(b.date) || a.name.localeCompare(b.name) ||
    a.scope.localeCompare(b.scope));
  return output;
}

function getHolidays(options = {}) {
  const resolution = resolveCountry({
    override: options.country || "auto",
    timezone: options.timezone,
    territory: options.territory,
    env: options.env
  });
  if (resolution.status !== "ok")
    fail(resolution.status === "ambiguous" ? "country-ambiguous" : "country-unresolved",
      resolution.status === "ambiguous" ? "timezone maps to multiple countries; configure a country override"
        : "timezone could not be mapped to a supported country", resolution);
  const country = resolution.country;
  const subdivision = normalizeSubdivision(options.subdivision);
  const year = normalizeYear(options.year);
  const showNational = normalizeBoolean(options.showNational, true);
  const showRegional = normalizeBoolean(options.showRegional, !!subdivision);
  const categories = categoryKey(showNational, showRegional);
  let selectedProvider;
  try {
    selectedProvider = regionalProvider.selectProvider(country, subdivision, year, {
      datasetVersion: dataset.version,
      dataRoot: options.regionalDataRoot,
      readFile: options.regionalReadFile,
      env: options.env
    });
  } catch (error) {
    fail(error.code || "regional-provider-failed", error.message, error.details || {});
  }
  const expected = {
    country, subdivision, year, categoryKey: categories,
    providerFingerprint: selectedProvider.fingerprint
  };
  const file = cachePath(country, subdivision, year, categories, options.env, selectedProvider.fingerprint);
  const cached = readCache(file, expected);
  if (cached) return { ...cached, cached: true, detection: resolution, cachePath: file };
  const merged = selectedProvider.kind === "official"
    ? mergeRegionalProvider(country, subdivision,
      classifyHolidays(country, "", year, { factory: options.factory }), selectedProvider)
    : selectedProvider.records
      ? mergeRegionalProvider(country, subdivision,
        classifyHolidays(country, subdivision, year, { factory: options.factory }), selectedProvider)
      : classifyHolidays(country, subdivision, year, { factory: options.factory });
  const holidays = merged
    .filter(row => (row.scope === "national" && showNational) ||
      (row.scope === "regional" && showRegional));
  const states = holidayCatalog.getStates(country) || {};
  const value = {
    schemaVersion: SCHEMA_VERSION,
    datasetVersion: dataset.version,
    country,
    countryName: String(holidayCatalog.getCountries()[country] || country),
    subdivision: subdivision || null,
    subdivisionName: subdivision ? String(states[subdivision] || subdivision) : null,
    year,
    categoryKey: categories,
    categories: { showNational, showRegional },
    provider: {
      kind: selectedProvider.kind,
      id: selectedProvider.id,
      source: selectedProvider.source
    },
    providerFingerprint: selectedProvider.fingerprint,
    holidays
  };
  writeJsonAtomic(file, value);
  return { ...value, cached: false, detection: resolution, cachePath: file };
}

function parseArgs(argv) {
  const options = { _: [] };
  for (let i = 0; i < argv.length; i++) {
    const key = argv[i];
    if (!key.startsWith("--")) {
      options._.push(key);
      continue;
    }
    if (i + 1 >= argv.length) fail("invalid-arguments", `missing value for ${key}`);
    options[key.substring(2)] = argv[++i];
  }
  return options;
}

function main(argv) {
  const command = argv.shift();
  if (command === "state-write") return writeStateFromStdin(argv);
  const args = parseArgs(argv);
  if (command === "countries") {
    if (args._.length) fail("invalid-arguments", "countries accepts no positional arguments");
    let detection;
    try { detection = resolveCountry({ override: "auto", timezone: args.timezone, territory: args.territory }); }
    catch (error) {
      if (!(error instanceof HelperError)) throw error;
      detection = { status: "unresolved", country: null, reason: error.code, message: error.message };
    }
    const metadata = cachedMetadata("countries", "", countries);
    return {
      datasetVersion: dataset.version,
      countries: metadata.items,
      cached: metadata.cached,
      cachePath: metadata.cachePath,
      detection
    };
  }
  if (command === "subdivisions") {
    const country = args.country || args._[0];
    if (!country || args._.length > 1) fail("invalid-arguments", "subdivisions requires one country");
    const normalized = normalizeCountry(country);
    const metadata = cachedMetadata("subdivisions", normalized, () => subdivisions(normalized));
    return {
      datasetVersion: dataset.version,
      countryCode: normalized,
      subdivisions: metadata.items,
      cached: metadata.cached,
      cachePath: metadata.cachePath
    };
  }
  if (command === "detect") return resolveCountry({
    override: args.country || "auto", timezone: args.timezone, territory: args.territory
  });
  if (command !== "get" && command !== "holidays")
    fail("invalid-command", "expected countries, subdivisions, detect, get, holidays, or state-write");
  const positionalCountry = args._[0];
  const positionalYear = args._[1];
  const positionalSubdivision = args._[2];
  if (args._.length > 3) fail("invalid-arguments", "too many holiday arguments");
  const allowedHolidayArgs = new Set([
    "_", "country", "year", "subdivision", "show-national", "show-regional",
    "timezone", "territory"
  ]);
  for (const key of Object.keys(args))
    if (!allowedHolidayArgs.has(key)) fail("invalid-arguments", `unsupported holiday option: --${key}`);
  return getHolidays({
    country: args.country || positionalCountry || "auto",
    year: args.year || positionalYear,
    subdivision: args.subdivision || positionalSubdivision || "",
    showNational: args["show-national"],
    showRegional: args["show-regional"],
    timezone: args.timezone,
    territory: args.territory
  });
}

if (require.main === module) {
  try {
    process.stdout.write(`${JSON.stringify({ ok: true, ...main(process.argv.slice(2)) })}\n`);
  } catch (error) {
    const code = error instanceof HelperError ? error.code : "internal-error";
    const message = error instanceof HelperError ? error.message : "holiday helper failed";
    process.stderr.write(`holiday-helper: ${code}: ${message}\n`);
    process.stdout.write(`${JSON.stringify({ ok: false, error: { code, message, details: error.details || {} } })}\n`);
    process.exitCode = 1;
  }
}

module.exports = {
  HelperError, cacheKey, cachePath, cachedMetadata, canonicalTimezone, categoryKey, classifyHolidays,
  countries, detectTimezone, generate, getHolidays, holidayIdentity, officialComparisonIdentity, localeTerritory,
  metadataCachePath, normalizeHolidayRows, mergeRegionalProvider, parseZoneTable, readCache,
  resolveCountry, subdivisions,
  validIanaZone, writeJsonAtomic, writeStateFromStdin
};
