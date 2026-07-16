.pragma library

function parseRows(text) {
    var result = []
    var lines = String(text || "").split("\n")
    for (var i = 0; i < lines.length; i++) {
        if (!lines[i]) continue
        var fields = lines[i].split("\t")
        if (fields.length < 2 || !fields[0]) continue
        result.push({ path: fields[0], label: fields.slice(1).join(" ").trim() || "Wallpaper" })
    }
    return result
}

function indexForPath(items, path) {
    var wanted = String(path || "").trim()
    for (var i = 0; i < items.length; i++) if (items[i].path === wanted) return i
    return items.length ? 0 : -1
}

function wrapped(index, count) {
    return count ? ((index % count) + count) % count : -1
}
