const assert = require("assert");
const model = require("../versions/default/services/NetworkModel.js");

const parsed = model.parseKeyValue(
  "iface\tenp0s1\nip\t192.0.2.20\nrx_bytes\t1000\ntx_bytes\t400\ninternet_ping_ms\t2.3\n"
);
assert.strictEqual(parsed.iface, "enp0s1");
assert.strictEqual(parsed.internet_ping_ms, "2.3");

let state = model.throughputState({}, parsed, 1000);
assert.strictEqual(state.downloadRate, 0);
assert.strictEqual(state.uploadRate, 0);

state = model.throughputState(state, {
  iface: "enp0s1", rx_bytes: "3048", tx_bytes: "1424"
}, 2000);
assert.strictEqual(state.downloadRate, 2048);
assert.strictEqual(state.uploadRate, 1024);

state = model.throughputState(state, {
  iface: "enp0s1", rx_bytes: "10", tx_bytes: "5"
}, 3000);
assert.strictEqual(state.downloadRate, 0, "counter reset must not create a negative rate");

state = model.throughputState(state, {
  iface: "wlan0", rx_bytes: "9000", tx_bytes: "8000"
}, 4000);
assert.strictEqual(state.downloadRate, 0, "interface switch must reset rate");

let ping = model.pingState([], "2.3", 4);
assert.strictEqual(ping.latency, 2.3);
assert.strictEqual(ping.packetLoss, 0);
ping = model.pingState(ping.samples, "", 4);
assert.strictEqual(ping.packetLoss, 50);
ping = model.pingState(ping.samples, "3.7", 4);
assert.strictEqual(ping.latency, 3);

const open = 0;
const secured = 2;
const enterprise = 3;
const networks = model.normalizeNetworks([
  { name: "", signalStrength: 0.9, security: open },
  { name: "Current", connected: true, signalStrength: 0.9, security: secured },
  { name: "Cafe", signalStrength: 0.3, security: open },
  { name: "Cafe", signalStrength: 0.8, security: secured },
  { name: "Unicode-网络", signalStrength: 0.6, security: enterprise },
  { name: "Bad\u0007Name", signalStrength: 0.4, security: secured }
], "Current", open, [enterprise]);

assert.deepStrictEqual(networks.map(n => n.ssid), ["Cafe", "Unicode-网络", "BadName"]);
assert.strictEqual(networks[0].signal, 80, "strongest duplicate BSSID wins");
assert.strictEqual(networks[0].secured, true);
assert.strictEqual(networks[1].enterprise, true);
assert.ok(!networks.some(n => n.ssid === "Current"), "current SSID excluded");

const nmcliRows = model.parseNmcliWifi(
  "Cafe\\:West:82:WPA2\nUnicode-网络:61:--\nCurrent:55:WPA2\n", "Current"
);
assert.strictEqual(nmcliRows[0].name, "Cafe:West");
assert.strictEqual(nmcliRows[0].security, 1);
assert.strictEqual(nmcliRows[1].security, 0);

assert.strictEqual(model.validCustomDns("1.1.1.1 2606:4700:4700::1111"), true);
assert.strictEqual(model.validCustomDns("999.1.1.1"), false);
assert.strictEqual(model.validCustomDns("not-a-server"), false);
assert.strictEqual(model.formatBytes(0), "0 B");
assert.strictEqual(model.formatBytes(1048576), "1.0 MiB");

console.log("PASS: network model parsing, rates, SSID normalization and DNS validation");
