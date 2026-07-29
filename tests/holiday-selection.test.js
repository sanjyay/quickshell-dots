"use strict";

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");
const vm = require("node:vm");

const source = fs.readFileSync(path.join(__dirname,
  "../versions/default/services/HolidaySelection.js"), "utf8");
const model = {};
vm.createContext(model);
vm.runInContext(source, model);

test("automatic selection uses detection and manual selection overrides it", () => {
  const initial = model.defaults({ countryMode: "auto" });
  assert.equal(model.effectiveCountry(initial, "IN", ["IN", "JP"]), "IN");
  const manual = model.selectCountry(initial, "JP");
  assert.equal(model.effectiveCountry(manual, "IN", ["IN", "JP"]), "JP");
  assert.equal(model.effectiveCountry(manual, "US", ["IN", "JP", "US"]), "JP");
  const automatic = model.useAutomatic(manual, false);
  assert.equal(model.effectiveCountry(automatic, "US", ["IN", "JP", "US"]), "US");
});

test("legacy Tamil Nadu selection migrates regional visibility and ignores old bank state", () => {
  const state = {
    schemaVersion: 1,
    countryMode: "manual",
    country: "IN",
    subdivision: "TN",
    showNational: true,
    showRegional: false,
    showBank: true
  };
  const restored = model.restore(JSON.parse(JSON.stringify(state)), {});
  assert.equal(restored.countryMode, "manual");
  assert.equal(restored.country, "IN");
  assert.equal(model.effectiveSubdivision(restored, ["TN", "KA"]), "TN");
  assert.equal(restored.showRegional, true);
  assert.equal(restored.regionalExplicit, false);
  assert.equal("showBank" in restored, false);
});

test("selecting Tamil Nadu enables regional holidays and persists in schema two", () => {
  const india = model.selectSubdivision(model.selectCountry(model.defaults({}), "IN"), "TN");
  assert.equal(india.subdivision, "TN");
  assert.equal(india.showRegional, true);
  const persisted = {
    schemaVersion: 2,
    countryMode: india.countryMode,
    country: india.country,
    subdivision: india.subdivision,
    showNational: india.showNational,
    showRegional: india.showRegional,
    regionalExplicit: india.regionalExplicit
  };
  const restored = model.restore(JSON.parse(JSON.stringify(persisted)), {});
  assert.equal(restored.subdivision, "TN");
  assert.equal(restored.showRegional, true);
});

test("country changes clear incompatible subdivisions", () => {
  const india = model.selectSubdivision(model.selectCountry(model.defaults({}), "IN"), "TN");
  const japan = model.selectCountry(india, "JP");
  assert.equal(japan.country, "JP");
  assert.equal(japan.subdivision, "");
});

test("manual regional disable is preserved only after the migrated schema", () => {
  const india = model.selectSubdivision(model.selectCountry(model.defaults({}), "IN"), "TN");
  const disabled = model.setCategories(india, true, false);
  assert.equal(disabled.showRegional, false);
  assert.equal(disabled.regionalExplicit, true);
  const restored = model.restore({
    schemaVersion: 2,
    countryMode: disabled.countryMode,
    country: disabled.country,
    subdivision: disabled.subdivision,
    showNational: disabled.showNational,
    showRegional: disabled.showRegional,
    regionalExplicit: disabled.regionalExplicit
  }, {});
  assert.equal(restored.showRegional, false);
  assert.equal(restored.regionalExplicit, true);
});

test("returning to automatic India preserves Tamil Nadu, another country does not", () => {
  const india = model.selectSubdivision(model.selectCountry(model.defaults({}), "IN"), "TN");
  const automaticIndia = model.useAutomatic(india, true);
  assert.equal(automaticIndia.countryMode, "auto");
  assert.equal(automaticIndia.subdivision, "TN");
  assert.equal(model.effectiveCountry(automaticIndia, "IN", ["IN", "JP"]), "IN");
  const automaticJapan = model.useAutomatic(india, false);
  assert.equal(automaticJapan.subdivision, "");
  assert.equal(model.effectiveCountry(automaticJapan, "JP", ["IN", "JP"]), "JP");
});

test("invalid persisted codes are controlled and never become effective", () => {
  const restored = model.restore({
    schemaVersion: 1,
    countryMode: "manual",
    country: "INVALID",
    subdivision: "../../bad",
    showNational: true
  }, {});
  assert.equal(restored.country, "");
  assert.equal(restored.subdivision, "");
  assert.equal(model.effectiveCountry(restored, "IN", ["IN"]), "");
  assert.equal(model.effectiveSubdivision(restored, ["TN"]), "");
});

test("legacy defaults infer manual mode only for a valid configured country", () => {
  assert.equal(model.defaults({ country: "IN" }).countryMode, "manual");
  assert.equal(model.defaults({ country: "auto" }).countryMode, "auto");
  assert.equal(model.defaults({ countryMode: "manual", country: "JP" }).country, "JP");
});
