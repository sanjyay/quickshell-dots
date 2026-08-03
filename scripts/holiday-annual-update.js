#!/usr/bin/env node
"use strict";

const childProcess = require("child_process");
const fs = require("fs");
const https = require("https");
const os = require("os");
const path = require("path");
const provider = require("./regional-holiday-provider.js");

const DEFAULT_URL =
  "https://raw.githubusercontent.com/sanjyay/quickshell-astra/main/data/holidays/{country}/{subdivision}/{year}.json";
const MAX_BYTES = 1024 * 1024;

function parseArgs(argv) {
  const result = {};
  for (let i = 0; i < argv.length; i++) {
    const key = argv[i];
    if (!key.startsWith("--") || i + 1 >= argv.length)
      throw new Error("expected --year, --country, --subdivision, --input, or --source-url");
    result[key.slice(2)] = argv[++i];
  }
  return result;
}

function atomicWrite(file, text, mode = 0o600) {
  fs.mkdirSync(path.dirname(file), { recursive: true, mode: 0o700 });
  const temporary = path.join(path.dirname(file), `.${path.basename(file)}.${process.pid}.${Date.now()}`);
  try {
    fs.writeFileSync(temporary, text, { mode });
    fs.renameSync(temporary, file);
  } finally {
    try { fs.unlinkSync(temporary); } catch (_) {}
  }
}

function fetchText(url, redirects = 0) {
  return new Promise((resolve, reject) => {
    if (redirects > 3) return reject(new Error("too many redirects"));
    const request = https.get(url, {
      headers: { "User-Agent": "quickshell-astra-holiday-updater/1" },
      timeout: 15000
    }, response => {
      if ([301, 302, 307, 308].includes(response.statusCode) && response.headers.location) {
        response.resume();
        return fetchText(new URL(response.headers.location, url).toString(), redirects + 1)
          .then(resolve, reject);
      }
      if (response.statusCode === 404) {
        response.resume();
        const error = new Error("no verified annual holiday file is published yet");
        error.code = "not-published";
        return reject(error);
      }
      if (response.statusCode !== 200) {
        response.resume();
        return reject(new Error(`holiday source returned HTTP ${response.statusCode}`));
      }
      const chunks = [];
      let size = 0;
      response.on("data", chunk => {
        size += chunk.length;
        if (size > MAX_BYTES) request.destroy(new Error("holiday source exceeds size limit"));
        else chunks.push(chunk);
      });
      response.on("end", () => resolve(Buffer.concat(chunks).toString("utf8")));
    });
    request.on("timeout", () => request.destroy(new Error("holiday source timed out")));
    request.on("error", reject);
  });
}

function notify(title, message, urgency = "normal") {
  childProcess.spawnSync("notify-send", [
    "-a", "Quickshell Astra", "-u", urgency, title, message
  ], { stdio: "ignore", timeout: 3000 });
}

function statePath(env) {
  return path.join(env.XDG_STATE_HOME || path.join(env.HOME || os.homedir(), ".local/state"),
    "quickshell-astra", "holiday-annual-update.json");
}

function clearYearCache(country, subdivision, year, env) {
  const directory = path.join(
    env.XDG_CACHE_HOME || path.join(env.HOME || os.homedir(), ".cache"),
    "quickshell-astra", "holidays");
  let removed = 0;
  try {
    for (const name of fs.readdirSync(directory)) {
      if (!name.startsWith(`${country}_${subdivision}_${year}_`) || !name.endsWith(".json")) continue;
      fs.unlinkSync(path.join(directory, name));
      removed++;
    }
  } catch (error) {
    if (!error || error.code !== "ENOENT") throw error;
  }
  return removed;
}

async function update(options = {}) {
  const env = options.env || process.env;
  const now = options.now || new Date();
  const year = Number(options.year || now.getFullYear());
  const country = String(options.country || "IN").toUpperCase();
  const subdivision = String(options.subdivision || "TN").toUpperCase();
  if (!Number.isInteger(year) || year < 1900 || year > 2200)
    throw new Error("year must be an integer between 1900 and 2200");
  if (!/^[A-Z]{2}$/.test(country) || !/^[A-Z0-9-]{1,12}$/.test(subdivision))
    throw new Error("country or subdivision code is invalid");

  const template = options.sourceUrl || env.QS_ASTRA_HOLIDAY_UPDATE_URL || DEFAULT_URL;
  const url = template
    .replaceAll("{country}", country)
    .replaceAll("{subdivision}", subdivision)
    .replaceAll("{year}", String(year));
  let text;
  if (options.input) text = fs.readFileSync(path.resolve(options.input), "utf8");
  else {
    let parsedUrl;
    try { parsedUrl = new URL(url); }
    catch (_) { throw new Error("annual holiday source URL is invalid"); }
    if (parsedUrl.protocol !== "https:")
      throw new Error("annual holiday source must use HTTPS");
    text = await (options.fetchText || fetchText)(parsedUrl.toString());
  }
  let parsed;
  try { parsed = JSON.parse(text); }
  catch (_) { throw new Error("downloaded holiday data is malformed JSON"); }
  const validated = provider.validateDataset(parsed, { country, subdivision, year });
  const dataRoot = options.dataRoot || provider.userDataRoot(env);
  const target = provider.datasetPath(country, subdivision, year, dataRoot);
  atomicWrite(target, `${JSON.stringify(validated, null, 2)}\n`);
  const cachesRemoved = clearYearCache(country, subdivision, year, env);
  return {
    status: "updated",
    year,
    country,
    subdivision,
    providerId: validated.providerId,
    holidays: validated.holidays.length,
    target,
    sourceUrl: url,
    cachesRemoved,
    checkedAt: now.toISOString()
  };
}

async function main(argv, env = process.env) {
  const args = parseArgs(argv);
  const checkedAt = new Date();
  let result;
  try {
    result = await update({
      year: args.year,
      country: args.country,
      subdivision: args.subdivision,
      input: args.input,
      sourceUrl: args["source-url"],
      env,
      now: checkedAt
    });
    const restart = childProcess.spawnSync("omarchy", ["restart", "shell"], {
      stdio: "ignore", timeout: 20000
    });
    result.shellRestarted = restart.status === 0;
    notify("Holiday calendar updated",
      `${result.holidays} verified ${result.subdivision} holidays installed for ${result.year}.`);
  } catch (error) {
    if (error && error.code === "not-published") {
      result = {
        status: "not-published",
        year: Number(args.year || checkedAt.getFullYear()),
        country: String(args.country || "IN").toUpperCase(),
        subdivision: String(args.subdivision || "TN").toUpperCase(),
        message: error.message,
        checkedAt: checkedAt.toISOString()
      };
      notify("Holiday calendar update",
        `No verified Tamil Nadu holiday file is available for ${result.year}; existing fallback remains active.`);
    } else {
      result = {
        status: "error",
        year: Number(args.year || checkedAt.getFullYear()),
        message: error.message,
        checkedAt: checkedAt.toISOString()
      };
      notify("Holiday calendar update failed", error.message, "critical");
      process.exitCode = 1;
    }
  }
  atomicWrite(statePath(env), `${JSON.stringify(result, null, 2)}\n`);
  process.stdout.write(`${JSON.stringify(result)}\n`);
  return result;
}

if (require.main === module) main(process.argv.slice(2));

module.exports = {
  DEFAULT_URL,
  atomicWrite,
  clearYearCache,
  fetchText,
  parseArgs,
  statePath,
  update
};
