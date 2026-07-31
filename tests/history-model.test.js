#!/usr/bin/env node
const assert = require("node:assert/strict");
const Model = require("../versions/default/panels/HistoryModel.js");

function row(type, timestamp, sequence, extra = {}) {
  return Model.event(Object.assign({ type, source: "fixture", sourcePath: `/fixture/${type}-${timestamp}`,
    eventStartedAtMs: timestamp, sortTimestampMs: timestamp, insertionSequence: sequence,
    state: "complete", previewState: "not-requested", title: type }, extra));
}

assert.equal(Model.finiteMs(1710000000), 1710000000000, "seconds normalize to milliseconds");
assert.equal(Model.finiteMs(1710000000000), 1710000000000, "milliseconds remain milliseconds");
assert.equal(Model.finiteMs(0), 0, "zero is invalid");
assert.equal(Model.recordingStartMs("malformed.mp4"), 0, "malformed recording timestamp falls back");
const parsed = Model.recordingStartMs("screenrecording-2026-08-01_00-00-01.mp4");
assert.equal(parsed, new Date(2026, 7, 1, 0, 0, 1).getTime(), "filename timestamp uses local time across date boundary");

let values = Model.sorted([row("clipboard", 1000, 1), row("screenshot", 2000, 2), row("recording", 3000, 3)]);
assert.deepEqual(values.map(x => x.type), ["recording", "screenshot", "clipboard"], "newest mixed event is first");

const historyMtime = 400000;
values = Model.sorted([row("clipboard", historyMtime, 3), row("clipboard", historyMtime - 60000, 2),
  row("recording", historyMtime - 10000, 4)]);
assert.deepEqual(values.map(x => x.type), ["clipboard", "recording", "clipboard"],
  "legacy clipboard order is anchored without compressing old rows into one second");

values = Model.sorted([row("recording", 1000, 1, { eventCompletedAtMs: 3000 }), row("clipboard", 2000, 2)]);
assert.deepEqual(values.map(x => x.type), ["clipboard", "recording"], "recording completion never changes capture-start order");

values = Model.sorted([row("clipboard", 1000, 1, { id: "b" }), row("screenshot", 1000, 2, { id: "a" })]);
assert.deepEqual(values.map(x => x.insertionSequence), [2, 1], "insertion sequence breaks timestamp ties");
values = Model.sorted([row("clipboard", 1000, 1, { id: "b" }), row("screenshot", 1000, 1, { id: "a" })]);
assert.deepEqual(values.map(x => x.id), ["a", "b"], "id is the final stable tie-breaker");

const start = Model.recordingStartMs("screenrecording-2026-07-31_21-00-00.mp4");
const active = row("recording", start, 8, { id: Model.eventId("recording", "/fixture/tmp.mp4", start),
  sourcePath: "/fixture/tmp.mp4", state: "recording-active", previewState: "waiting-for-final-file" });
const complete = row("recording", start, 99, { id: Model.eventId("recording", "/fixture/final.mp4", start),
  sourcePath: "/fixture/final.mp4", state: "recording-complete", previewState: "not-requested" });
let reconciled = Model.reconcile([active], [complete]);
assert.equal(reconciled.length, 1, "completion does not duplicate recording");
assert.equal(reconciled[0].id, active.id, "temporary/final paths share logical recording identity");
assert.equal(reconciled[0].state, "recording-complete", "active placeholder upgrades to complete");
assert.equal(reconciled[0].insertionSequence, 8, "upgrade retains insertion identity");

const generating = Object.assign({}, active, { previewState: "generating" });
reconciled = Model.reconcile([generating], [complete]);
assert.equal(reconciled[0].previewState, "generating", "preview role remains reactive across rebuild");
const incomingReady = Object.assign({}, complete, { previewState: "ready", previewPath: "/fixture/new-thumb.jpg" });
reconciled = Model.reconcile([generating], [incomingReady]);
assert.equal(reconciled[0].previewState, "ready", "worker completion overrides stale generating delegate state");
const ready = Object.assign({}, active, { previewState: "ready", previewPath: "/fixture/thumb.jpg" });
reconciled = Model.reconcile([ready], [complete]);
assert.equal(reconciled[0].previewState, "ready", "failed/empty source can transition to ready");
assert.equal(reconciled[0].previewPath, "/fixture/thumb.jpg");

values = Model.sorted([row("recording", 0, 100), row("clipboard", 1, 1)]);
assert.deepEqual(values.map(x => x.type), ["clipboard"], "invalid zero timestamps cannot become newest");
console.log("PASS: normalized history ordering, identity, completion, and preview transitions");
