function finiteMs(value) {
    var number = Number(value)
    if (!isFinite(number) || number <= 0) return 0
    return number < 100000000000 ? Math.round(number * 1000) : Math.round(number)
}

function recordingStartMs(name) {
    var match = String(name || "").match(/^screenrecording-(\d{4})-(\d{2})-(\d{2})_(\d{2})-(\d{2})-(\d{2})(?:\.[^.]+)?$/)
    if (!match) return 0
    var date = new Date(Number(match[1]), Number(match[2]) - 1, Number(match[3]),
        Number(match[4]), Number(match[5]), Number(match[6]))
    return finiteMs(date.getTime())
}

function eventId(type, sourcePath, startedAtMs) {
    if (type === "recording" && startedAtMs > 0) return "recording:" + startedAtMs
    return type + ":" + String(sourcePath || startedAtMs)
}

function event(values) {
    var sourcePath = String(values.sourcePath || "")
    var started = finiteMs(values.eventStartedAtMs)
    var insertion = Number(values.insertionSequence) || 0
    return {
        id: String(values.id || eventId(values.type, sourcePath, started)),
        type: String(values.type || "other"),
        kind: String(values.kind || values.type || "other"),
        source: String(values.source || "unknown"),
        sourcePath: sourcePath,
        filePath: sourcePath,
        eventStartedAtMs: started,
        eventCompletedAtMs: finiteMs(values.eventCompletedAtMs),
        sortTimestampMs: finiteMs(values.sortTimestampMs) || started,
        insertionSequence: insertion,
        state: String(values.state || "complete"),
        previewState: String(values.previewState || "not-requested"),
        previewPath: String(values.previewPath || ""),
        imagePath: String(values.previewPath || values.imagePath || ""),
        title: String(values.title || "History event"),
        subtitle: String(values.subtitle || ""),
        label: String(values.title || values.label || "History event"),
        detail: String(values.subtitle || values.detail || ""),
        fullText: String(values.fullText || ""),
        previewText: String(values.previewText || ""),
        mimeType: String(values.mimeType || ""),
        nativeHistoryIndex: Number(values.nativeHistoryIndex),
        timestamp: String(values.timestamp || ""),
        searchKeywords: String(values.searchKeywords || "").toLowerCase(),
        icon: String(values.icon || "󰋼"),
        isSensitive: values.isSensitive === true,
        isDeleted: values.isDeleted === true,
        timestampFallback: String(values.timestampFallback || "")
    }
}

function compare(a, b) {
    var at = finiteMs(a.sortTimestampMs)
    var bt = finiteMs(b.sortTimestampMs)
    if (at !== bt) return bt - at
    var ai = Number(a.insertionSequence) || 0
    var bi = Number(b.insertionSequence) || 0
    if (ai !== bi) return bi - ai
    return String(a.id).localeCompare(String(b.id))
}

function sorted(events) {
    return (Array.isArray(events) ? events : []).filter(function(row) {
        return row && !row.isDeleted && finiteMs(row.sortTimestampMs) > 0
    }).slice().sort(compare)
}

function reconcile(previous, incoming) {
    var oldById = {}
    ;(Array.isArray(previous) ? previous : []).forEach(function(row) { oldById[row.id] = row })
    return (Array.isArray(incoming) ? incoming : []).map(function(row) {
        var old = oldById[row.id]
        if (!old) return row
        var next = Object.assign({}, row)
        if (next.previewState === "ready" || next.previewState === "generating"
                || next.previewState === "retryable-failure" || next.previewState === "permanent-failure") {
            return next
        }
        if (old.previewState === "ready" && old.previewPath) {
            next.previewState = "ready"
            next.previewPath = old.previewPath
            next.imagePath = old.previewPath
        } else if (old.previewState === "generating" || old.previewState === "retryable-failure") {
            next.previewState = old.previewState
        }
        next.insertionSequence = old.insertionSequence
        return next
    })
}

if (typeof module !== "undefined") module.exports = {
    finiteMs: finiteMs,
    recordingStartMs: recordingStartMs,
    eventId: eventId,
    event: event,
    compare: compare,
    sorted: sorted,
    reconcile: reconcile
}
