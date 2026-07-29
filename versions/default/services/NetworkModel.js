function parseKeyValue(raw) {
    var result = {}
    var lines = String(raw || "").split("\n")
    for (var i = 0; i < lines.length; i++) {
        var at = lines[i].indexOf("\t")
        if (at > 0) result[lines[i].substring(0, at)] = lines[i].substring(at + 1).trim()
    }
    return result
}

function throughputState(previous, sample, nowMs) {
    var old = previous || {}
    var next = sample || {}
    var iface = String(next.iface || "")
    var rx = Math.max(0, parseFloat(next.rx_bytes || "0") || 0)
    var tx = Math.max(0, parseFloat(next.tx_bytes || "0") || 0)
    var reset = iface !== String(old.iface || "") || Number(old.time || 0) <= 0
        || rx < Number(old.rx || 0) || tx < Number(old.tx || 0)
    var elapsed = (Number(nowMs) - Number(old.time || 0)) / 1000
    return {
        iface: iface,
        rx: rx,
        tx: tx,
        time: Number(nowMs),
        downloadRate: reset || elapsed <= 0 ? 0 : Math.max(0, (rx - Number(old.rx || 0)) / elapsed),
        uploadRate: reset || elapsed <= 0 ? 0 : Math.max(0, (tx - Number(old.tx || 0)) / elapsed)
    }
}

function pingState(previousSamples, raw, limit) {
    var samples = Array.isArray(previousSamples) ? previousSamples.slice() : []
    var value = parseFloat(raw)
    samples.push(isFinite(value) && value >= 0 ? value : null)
    while (samples.length > Math.max(1, limit || 8)) samples.shift()
    var total = 0
    var valid = 0
    var lost = 0
    for (var i = 0; i < samples.length; i++) {
        if (samples[i] === null) lost++
        else {
            total += samples[i]
            valid++
        }
    }
    return {
        samples: samples,
        latency: valid > 0 ? total / valid : -1,
        packetLoss: samples.length > 0 ? Math.round(lost * 100 / samples.length) : -1
    }
}

function sanitizeSsid(value) {
    return String(value || "").replace(/[\u0000-\u001f\u007f]/g, "").trim()
}

function normalizeNetworks(values, connectedSsid, openSecurity, enterpriseTypes) {
    var byName = {}
    var source = Array.isArray(values) ? values : []
    for (var i = 0; i < source.length; i++) {
        var network = source[i] || {}
        var name = sanitizeSsid(network.name)
        if (name === "" || network.connected || name === connectedSsid) continue
        var signal = Math.round((Number(network.signalStrength) || 0) * 100)
        var old = byName[name]
        if (!old || signal > old.signal) {
            byName[name] = {
                id: name,
                ssid: name,
                signal: signal,
                secured: network.security !== openSecurity,
                enterprise: enterpriseTypes.indexOf(network.security) >= 0,
                known: !!network.known,
                network: network
            }
        }
    }
    var result = []
    for (var key in byName) result.push(byName[key])
    result.sort(function(a, b) {
        if (a.signal !== b.signal) return b.signal - a.signal
        return a.ssid.localeCompare(b.ssid)
    })
    return result
}

function splitNmcliLine(line) {
    var fields = [""]
    var escaped = false
    var value = String(line || "")
    for (var i = 0; i < value.length; i++) {
        var character = value[i]
        if (escaped) {
            fields[fields.length - 1] += character
            escaped = false
        } else if (character === "\\") {
            escaped = true
        } else if (character === ":") {
            fields.push("")
        } else {
            fields[fields.length - 1] += character
        }
    }
    if (escaped) fields[fields.length - 1] += "\\"
    return fields
}

function parseNmcliWifi(raw, connectedSsid) {
    var rows = []
    var lines = String(raw || "").split("\n")
    for (var i = 0; i < lines.length; i++) {
        if (lines[i] === "") continue
        var fields = splitNmcliLine(lines[i])
        var name = sanitizeSsid(fields[0])
        if (name === "" || name === connectedSsid) continue
        var security = fields.slice(2).join(":")
        rows.push({
            name: name,
            signalStrength: Math.max(0, Math.min(100, parseInt(fields[1], 10) || 0)) / 100,
            security: security === "" || security === "--" ? 0 : 1,
            securityText: security,
            known: false,
            connected: false,
            fallback: true
        })
    }
    return rows
}

function validDnsAddress(value) {
    var address = String(value || "").trim()
    if (address === "") return false
    if (/^(\d{1,3}\.){3}\d{1,3}$/.test(address)) {
        var parts = address.split(".")
        for (var i = 0; i < parts.length; i++)
            if (parseInt(parts[i], 10) > 255) return false
        return true
    }
    if (!/^[0-9a-fA-F:]+$/.test(address) || address.indexOf(":") < 0) return false
    var groups = address.split(":")
    if (groups.length < 3 || groups.length > 8) return false
    for (var j = 0; j < groups.length; j++)
        if (groups[j].length > 4) return false
    return true
}

function validCustomDns(value) {
    var text = String(value || "").trim()
    if (text === "") return false
    var values = text.split(/[\s,]+/)
    for (var i = 0; i < values.length; i++)
        if (!validDnsAddress(values[i])) return false
    return true
}

function formatBytes(value) {
    var n = Math.max(0, Number(value) || 0)
    if (n < 1024) return Math.round(n) + " B"
    if (n < 1048576) return (n / 1024).toFixed(1) + " KiB"
    if (n < 1073741824) return (n / 1048576).toFixed(1) + " MiB"
    return (n / 1073741824).toFixed(2) + " GiB"
}

if (typeof module !== "undefined") {
    module.exports = {
        parseKeyValue: parseKeyValue,
        throughputState: throughputState,
        pingState: pingState,
        sanitizeSsid: sanitizeSsid,
        normalizeNetworks: normalizeNetworks,
        splitNmcliLine: splitNmcliLine,
        parseNmcliWifi: parseNmcliWifi,
        validDnsAddress: validDnsAddress,
        validCustomDns: validCustomDns,
        formatBytes: formatBytes
    }
}
