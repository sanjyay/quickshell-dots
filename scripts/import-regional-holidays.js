#!/usr/bin/env node
"use strict";

const fs = require("fs");
const path = require("path");
const provider = require("./regional-holiday-provider.js");

function fail(message) {
  process.stderr.write(`import-regional-holidays: ${message}\n`);
  process.exitCode = 1;
}

function options(argv) {
  const result = {};
  for (let i = 0; i < argv.length; i += 2) {
    if (!argv[i].startsWith("--") || i + 1 >= argv.length)
      throw new Error("expected --country, --subdivision, --year, and --input");
    result[argv[i].slice(2)] = argv[i + 1];
  }
  return result;
}

try {
  const args = options(process.argv.slice(2));
  if (!args.country || !args.subdivision || !args.year || !args.input)
    throw new Error("expected --country, --subdivision, --year, and --input");
  const input = JSON.parse(fs.readFileSync(path.resolve(args.input), "utf8"));
  const validated = provider.validateDataset(input, {
    country: String(args.country).toUpperCase(),
    subdivision: String(args.subdivision).toUpperCase(),
    year: Number(args.year)
  });
  process.stdout.write(`${JSON.stringify(validated, null, 2)}\n`);
} catch (error) {
  fail(error.message);
}
