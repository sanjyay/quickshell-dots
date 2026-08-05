function finiteNumber(value) {
    var number = Number(value)
    return isFinite(number) ? number : NaN
}

function clampBrightness(value) {
    var number = finiteNumber(value)
    if (!isFinite(number)) return 1
    return Math.max(1, Math.min(100, Math.round(number)))
}

function normalizeScale(value) {
    var number = finiteNumber(value)
    if (!isFinite(number) || number <= 0) return ""
    return String(Math.round(number * 100) / 100)
}

function parseMonitors(raw, outputName) {
    var monitors = []
    try {
        monitors = JSON.parse(String(raw || ""))
    } catch (error) {
        return { ok: false, monitors: [], selected: null, error: "malformed-monitor-json" }
    }
    if (!Array.isArray(monitors))
        return { ok: false, monitors: [], selected: null, error: "invalid-monitor-list" }

    var valid = []
    var selected = null
    for (var i = 0; i < monitors.length; i++) {
        var source = monitors[i]
        if (!source || typeof source !== "object") continue
        var name = String(source.name || "").trim()
        var width = finiteNumber(source.width)
        var height = finiteNumber(source.height)
        var scale = normalizeScale(source.scale)
        if (!name || !isFinite(width) || !isFinite(height) || !scale) continue
        var monitor = {
            name: name,
            description: String(source.description || source.model || name).trim() || name,
            width: Math.round(width),
            height: Math.round(height),
            refreshRate: finiteNumber(source.refreshRate),
            x: finiteNumber(source.x),
            y: finiteNumber(source.y),
            scale: scale,
            transform: Math.round(finiteNumber(source.transform) || 0),
            mirrorOf: String(source.mirrorOf || "none"),
            currentFormat: String(source.currentFormat || ""),
            disabled: source.disabled === true
        }
        valid.push(monitor)
        if (name === String(outputName || "")) selected = monitor
    }
    return {
        ok: valid.length > 0,
        monitors: valid,
        selected: selected,
        error: valid.length === 0 ? "no-monitors" : (selected ? "" : "output-not-found")
    }
}

function scaleIndex(scales, currentScale) {
    var normalized = normalizeScale(currentScale)
    if (!normalized || !Array.isArray(scales)) return -1
    for (var i = 0; i < scales.length; i++) {
        if (normalizeScale(scales[i]) === normalized) return i
    }
    return -1
}

function validTextSize(value, steps, fallback) {
    var number = Math.round(finiteNumber(value))
    if (!Array.isArray(steps) || steps.indexOf(number) < 0) return fallback
    return number
}

if (typeof module !== "undefined") {
    module.exports = {
        clampBrightness: clampBrightness,
        normalizeScale: normalizeScale,
        parseMonitors: parseMonitors,
        scaleIndex: scaleIndex,
        validTextSize: validTextSize
    }
}
