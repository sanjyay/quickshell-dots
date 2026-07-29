"use strict";

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");
const vm = require("node:vm");
const helper = require("../scripts/holiday-helper.js");

const source = fs.readFileSync(path.join(__dirname,
  "../versions/default/services/HolidayCalendarModel.js"), "utf8");
const model = {};
vm.createContext(model);
vm.runInContext(source, model);

function monthRows(year, month) {
  return Array.from(model.indianBankClosures(year))
    .filter(row => Number(row.date.slice(5, 7)) === month + 1);
}

function saturdays(year, month) {
  const days = [];
  const last = new Date(year, month + 1, 0).getDate();
  for (let day = 1; day <= last; day++)
    if (new Date(year, month, day).getDay() === 6) days.push(day);
  return days;
}

test("all 12 months mark exactly second and fourth Saturdays", () => {
  for (let month = 0; month < 12; month++) {
    const rows = monthRows(2026, month);
    const saturdayDays = saturdays(2026, month);
    const marked = rows.map(row => Number(row.date.slice(8, 10)));
    assert.deepEqual(marked, [saturdayDays[1], saturdayDays[3]]);
    assert.equal(rows.length, 2);
    for (const row of rows) {
      const parts = row.date.split("-").map(Number);
      assert.equal(parts[0], 2026);
      assert.equal(parts[1], month + 1);
      assert.equal(new Date(parts[0], parts[1] - 1, parts[2]).getDay(), 6);
      assert.match(row.date, /^\d{4}-\d{2}-\d{2}$/);
      assert.equal(row.type, "bank-closure");
      assert.equal(row.source, "rbi-saturday-rule");
    }
    assert.ok(!marked.includes(saturdayDays[0]));
    assert.ok(!marked.includes(saturdayDays[2]));
    if (saturdayDays[4]) assert.ok(!marked.includes(saturdayDays[4]));
  }
});

test("calendar shapes include Saturday-first, five-Saturday, normal and leap February", () => {
  assert.equal(new Date(2026, 7, 1).getDay(), 6);
  assert.deepEqual(monthRows(2026, 7).map(row => row.date), ["2026-08-08", "2026-08-22"]);
  assert.equal(saturdays(2026, 7).length, 5);
  assert.deepEqual(monthRows(2026, 1).map(row => row.date), ["2026-02-14", "2026-02-28"]);
  assert.deepEqual(monthRows(2024, 1).map(row => row.date), ["2024-02-10", "2024-02-24"]);
});

test("December and January stay within their intended year and month", () => {
  assert.deepEqual(monthRows(2025, 11).map(row => row.date), ["2025-12-13", "2025-12-27"]);
  assert.deepEqual(monthRows(2026, 0).map(row => row.date), ["2026-01-10", "2026-01-24"]);
});

test("bank closures are India-only and coexist with public holidays", () => {
  const holiday = {
    date: "2026-08-08",
    name: "Public Event",
    type: "public",
    scope: "national",
    countryCode: "IN"
  };
  const india = model.indexedModel([holiday], "IN", 2026);
  assert.equal(india["2026-08-08"].length, 2);
  assert.deepEqual(Array.from(model.markerClasses(india["2026-08-08"])),
    ["national", "bank-closure"]);
  const japan = model.indexedModel([], "JP", 2026);
  const unitedStates = model.indexedModel([], "US", 2026);
  assert.equal(Object.values(japan).flat().some(row => row.type === "bank-closure"), false);
  assert.equal(Object.values(unitedStates).flat().some(row => row.type === "bank-closure"), false);
});

test("real Tamil Nadu helper output reaches the date-indexed calendar model", () => {
  const payload = helper.getHolidays({
    country: "IN",
    subdivision: "TN",
    year: 2026,
    showNational: true,
    showRegional: true
  });
  const index = model.indexedModel(payload.holidays, payload.country, payload.year);
  assert.ok(index["2026-01-26"].some(row =>
    row.name === "Republic Day" && row.scope === "national"));
  assert.ok(index["2026-01-15"].some(row =>
    row.name === "Pongal" && row.scope === "regional"));
  assert.ok(index["2026-01-16"].some(row =>
    row.name === "Thiruvalluvar Day" && row.scope === "regional"));
  assert.ok(index["2026-04-14"].some(row =>
    row.name.startsWith("Tamil New Year's Day") && row.scope === "regional"));
  assert.ok(index["2026-05-01"].some(row =>
    row.name === "May Day" && row.scope === "regional" &&
    row.subdivisionCode === "TN" && row.subdivisionName === "Tamil Nadu"));
  assert.deepEqual(Array.from(model.markerClasses(index["2026-05-01"])), ["regional"]);
  assert.equal(Object.entries(index).some(([date, rows]) =>
    date.startsWith("2026-07") && rows.some(row => row.scope === "regional")), false);
  assert.ok(index["2026-09-14"].some(row =>
    row.name === "Vinayakar Chathurthi" && row.scope === "regional"));
  assert.ok(index["2026-10-19"].some(row =>
    row.name === "Ayutha Pooja" && row.scope === "regional"));
  assert.ok(index["2026-11-08"].some(row =>
    row.name === "Deepavali" && row.scope === "regional"));
  assert.ok(index["2026-08-08"].some(row =>
    row.type === "bank-closure" && row.description === "Second Saturday"));
  assert.ok(index["2026-08-22"].some(row =>
    row.type === "bank-closure" && row.description === "Fourth Saturday"));
});

test("empty holiday cache data cannot remove calculated India closures", () => {
  const index = model.indexedModel([], "IN", 2026);
  assert.equal(index["2026-08-08"][0].type, "bank-closure");
  assert.equal(index["2026-08-22"][0].type, "bank-closure");
});

test("January 2027 indexes Tamil Nadu New Year and national Republic Day", () => {
  const payload = helper.getHolidays({
    country: "IN", subdivision: "TN", year: 2027,
    showNational: true, showRegional: true
  });
  const index = model.indexedModel(payload.holidays, payload.country, payload.year);
  assert.ok(index["2027-01-01"].some(row =>
    row.name === "New Year's Day" && row.scope === "regional" &&
    row.source === "tn-recurring-fixed"));
  assert.ok(index["2027-01-26"].some(row =>
    row.name === "Republic Day" && row.scope === "national"));
  assert.deepEqual(Array.from(model.markerClasses(index["2027-01-01"])), ["regional"]);
});
