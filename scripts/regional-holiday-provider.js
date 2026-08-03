"use strict";

const fs = require("fs");
const path = require("path");

const DATA_ROOT = path.resolve(__dirname, "../data/holidays");

function userDataRoot(env = process.env) {
  return path.join(env.XDG_DATA_HOME || path.join(env.HOME || require("os").homedir(), ".local/share"),
    "quickshell-astra", "holidays");
}

class RegionalProviderError extends Error {
  constructor(code, message, details = {}) {
    super(message);
    this.code = code;
    this.details = details;
  }
}

function normalizeCode(value, pattern, label) {
  const code = String(value || "").trim().toUpperCase();
  if (!pattern.test(code)) throw new RegionalProviderError(`invalid-${label}`, `invalid ${label} code`);
  return code;
}

function datasetPath(countryValue, subdivisionValue, yearValue, dataRoot = DATA_ROOT) {
  const country = normalizeCode(countryValue, /^[A-Z]{2}$/, "country");
  const subdivision = normalizeCode(subdivisionValue, /^[A-Z0-9-]{1,12}$/, "subdivision");
  const year = Number(yearValue);
  if (!Number.isInteger(year) || year < 1900 || year > 2200)
    throw new RegionalProviderError("invalid-year", "invalid regional dataset year");
  return path.join(dataRoot, country, subdivision, `${year}.json`);
}

function validateDataset(value, expected = {}) {
  if (!value || value.schemaVersion !== 1 || !Number.isInteger(value.revision) ||
      value.revision < 1 || value.providerId === undefined)
    throw new RegionalProviderError("invalid-regional-dataset", "regional dataset metadata is invalid");
  const countryCode = normalizeCode(value.countryCode, /^[A-Z]{2}$/, "country");
  const subdivisionCode = normalizeCode(value.subdivisionCode, /^[A-Z0-9-]{1,12}$/, "subdivision");
  if (!Number.isInteger(value.year) || value.year < 1900 || value.year > 2200)
    throw new RegionalProviderError("invalid-regional-dataset", "regional dataset year is invalid");
  if ((expected.country && countryCode !== expected.country) ||
      (expected.subdivision && subdivisionCode !== expected.subdivision) ||
      (expected.year && value.year !== expected.year))
    throw new RegionalProviderError("regional-dataset-mismatch", "regional dataset does not match its path");
  if (!value.source || value.source.official !== true ||
      !String(value.source.publisher || "").trim() || !String(value.source.title || "").trim())
    throw new RegionalProviderError("invalid-regional-dataset", "regional source metadata is invalid");
  if (!Array.isArray(value.holidays))
    throw new RegionalProviderError("invalid-regional-dataset", "regional holidays must be an array");
  const seen = new Set();
  const holidays = value.holidays.map(row => {
    const date = String(row && row.date || "");
    const name = String(row && row.name || "").trim();
    const parts = date.split("-").map(Number);
    const parsed = parts.length === 3
      ? new Date(Date.UTC(parts[0], parts[1] - 1, parts[2])) : null;
    if (!/^\d{4}-\d{2}-\d{2}$/.test(date) || Number(date.slice(0, 4)) !== value.year ||
        !name || row.type !== "public" || row.scope !== "regional" ||
        !parsed || parsed.getUTCFullYear() !== parts[0] ||
        parsed.getUTCMonth() !== parts[1] - 1 || parsed.getUTCDate() !== parts[2])
      throw new RegionalProviderError("invalid-regional-dataset", `invalid regional holiday: ${date} ${name}`);
    const identity = `${date}\u001f${name.toLocaleLowerCase("en")}`;
    if (seen.has(identity))
      throw new RegionalProviderError("duplicate-regional-holiday", `duplicate regional holiday: ${date} ${name}`);
    seen.add(identity);
    return { date, name, type: "public", scope: "regional" };
  });
  holidays.sort((a, b) => a.date.localeCompare(b.date) || a.name.localeCompare(b.name, "en"));
  return {
    ...value,
    countryCode,
    subdivisionCode,
    subdivisionName: String(value.subdivisionName || subdivisionCode),
    providerId: String(value.providerId),
    holidays
  };
}

function loadOfficial(country, subdivision, year, options = {}) {
  if (!subdivision) return null;
  const roots = options.dataRoot
    ? [options.dataRoot]
    : [userDataRoot(options.env), DATA_ROOT];
  let file = "";
  let source = "";
  for (const root of roots) {
    const candidate = datasetPath(country, subdivision, year, root);
    try {
      source = (options.readFile || fs.readFileSync)(candidate, "utf8");
      file = candidate;
      break;
    } catch (error) {
      if (error && error.code === "ENOENT") continue;
      throw new RegionalProviderError("regional-dataset-read-failed", error.message, { file: candidate });
    }
  }
  if (!file) return null;
  let value;
  try { value = JSON.parse(source); }
  catch (_) { throw new RegionalProviderError("invalid-regional-json", "regional dataset is malformed", { file }); }
  const dataset = validateDataset(value, { country, subdivision, year });
  return {
    kind: "official",
    id: dataset.providerId,
    fingerprint: `${dataset.providerId}-schema${dataset.schemaVersion}-revision${dataset.revision}`,
    file,
    source: dataset.source,
    records: dataset.holidays.map(row => ({
      ...row,
      countryCode: dataset.countryCode,
      subdivisionCode: dataset.subdivisionCode,
      subdivisionName: dataset.subdivisionName,
      source: dataset.providerId
    }))
  };
}

function loadRecurring(country, subdivision, year, options = {}) {
  if (!subdivision) return null;
  const file = path.join(options.dataRoot || DATA_ROOT, country, subdivision, "recurring.json");
  let value;
  try {
    value = JSON.parse((options.readFile || fs.readFileSync)(file, "utf8"));
  } catch (error) {
    if (error && error.code === "ENOENT") return null;
    throw new RegionalProviderError("invalid-recurring-regional-json",
      "recurring regional dataset is malformed", { file });
  }
  if (!value || value.schemaVersion !== 1 || !Number.isInteger(value.revision) ||
      value.countryCode !== country || value.subdivisionCode !== subdivision ||
      !String(value.providerId || "").trim() || !value.source ||
      value.source.officialAnnualList !== false || !Array.isArray(value.holidays))
    throw new RegionalProviderError("invalid-recurring-regional-dataset",
      "recurring regional dataset metadata is invalid", { file });
  const seen = new Set();
  const records = value.holidays.map(row => {
    const monthDay = String(row && row.monthDay || "");
    const name = String(row && row.name || "").trim();
    const date = `${year}-${monthDay}`;
    const parts = date.split("-").map(Number);
    const parsed = new Date(Date.UTC(parts[0], parts[1] - 1, parts[2]));
    if (!/^\d{2}-\d{2}$/.test(monthDay) || !name ||
        row.type !== "public" || row.scope !== "regional" ||
        parsed.getUTCFullYear() !== year || parsed.getUTCMonth() !== parts[1] - 1 ||
        parsed.getUTCDate() !== parts[2])
      throw new RegionalProviderError("invalid-recurring-regional-dataset",
        `invalid recurring regional holiday: ${monthDay} ${name}`, { file });
    const identity = `${monthDay}\u001f${name.toLocaleLowerCase("en")}`;
    if (seen.has(identity))
      throw new RegionalProviderError("duplicate-recurring-regional-holiday",
        `duplicate recurring regional holiday: ${monthDay} ${name}`, { file });
    seen.add(identity);
    return {
      date,
      name,
      type: "public",
      scope: "regional",
      countryCode: country,
      subdivisionCode: subdivision,
      subdivisionName: String(value.subdivisionName || subdivision),
      source: String(value.providerId)
    };
  }).sort((a, b) => a.date.localeCompare(b.date) || a.name.localeCompare(b.name, "en"));
  return {
    kind: "recurring-fallback",
    id: String(value.providerId),
    fingerprint: `${value.providerId}-schema${value.schemaVersion}-revision${value.revision}`,
    file,
    source: value.source,
    records
  };
}

function selectProvider(country, subdivision, year, options = {}) {
  const official = loadOfficial(country, subdivision, year, options);
  if (official) return official;
  const recurring = loadRecurring(country, subdivision, year, options);
  if (recurring) return {
    ...recurring,
    kind: "date-holidays+recurring-fallback",
    fingerprint: `date-holidays-${String(options.datasetVersion || "unknown")}+${recurring.fingerprint}`
  };
  return {
    kind: "date-holidays",
    id: "date-holidays",
    fingerprint: `date-holidays-${String(options.datasetVersion || "unknown")}`,
    source: null,
    records: null
  };
}

module.exports = {
  DATA_ROOT,
  RegionalProviderError,
  datasetPath,
  loadOfficial,
  loadRecurring,
  selectProvider,
  userDataRoot,
  validateDataset
};
