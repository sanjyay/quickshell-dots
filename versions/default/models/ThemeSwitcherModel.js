.pragma library

function parseRows(text) {
    var result = []
    var lines = String(text || "").split("\n")
    for (var i = 0; i < lines.length; i++) {
        if (!lines[i].trim()) continue
        var fields = lines[i].split("\t")
        if (fields.length < 3 || !fields[0].trim() || !fields[2].trim()) continue
        result.push({
            id: fields[0].trim(),
            label: fields[1].trim() || fields[0].trim(),
            preview: fields[2].trim(),
            directory: fields[3] ? fields[3].trim() : ""
        })
    }
    result.sort(function(a, b) {
        var left = a.label.toLowerCase()
        var right = b.label.toLowerCase()
        return left < right ? -1 : (left > right ? 1 : 0)
    })
    return result
}

function currentIndex(themes, currentId) {
    var id = String(currentId || "").trim().toLowerCase()
    for (var i = 0; i < themes.length; i++) {
        if (themes[i].id.toLowerCase() === id) return i
    }
    return themes.length > 0 ? 0 : -1
}

function indexForId(themes, id) {
    var wanted = String(id || "").trim().toLowerCase()
    if (!wanted) return -1
    for (var i = 0; i < themes.length; i++) {
        if (themes[i].id.toLowerCase() === wanted) return i
    }
    return -1
}

function validId(id) {
    return /^[A-Za-z0-9._-]+$/.test(String(id || ""))
}
