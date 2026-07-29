function pad(value, width) {
    return String(value).padStart(width, "0")
}

function localIsoDate(year, month, day) {
    return pad(year, 4) + "-" + pad(month + 1, 2) + "-" + pad(day, 2)
}

function saturdayDay(year, month, occurrence) {
    var firstWeekday = new Date(year, month, 1).getDay()
    var firstSaturday = 1 + ((6 - firstWeekday + 7) % 7)
    return firstSaturday + (occurrence - 1) * 7
}

function indianBankClosures(year) {
    var records = []
    for (var month = 0; month < 12; month++) {
        var second = saturdayDay(year, month, 2)
        var fourth = saturdayDay(year, month, 4)
        records.push({
            date: localIsoDate(year, month, second),
            name: "Banks closed",
            description: "Second Saturday",
            type: "bank-closure",
            scope: "national",
            countryCode: "IN",
            countryName: "India",
            subdivisionCode: "",
            subdivisionName: "",
            source: "rbi-saturday-rule",
            substitute: false
        })
        records.push({
            date: localIsoDate(year, month, fourth),
            name: "Banks closed",
            description: "Fourth Saturday",
            type: "bank-closure",
            scope: "national",
            countryCode: "IN",
            countryName: "India",
            subdivisionCode: "",
            subdivisionName: "",
            source: "rbi-saturday-rule",
            substitute: false
        })
    }
    return records
}

function indexedModel(holidays, countryCode, year) {
    var rows = []
    if (holidays)
        for (var i = 0; i < holidays.length; i++) rows.push(holidays[i])
    if (countryCode === "IN") {
        var closures = indianBankClosures(year)
        for (var closureIndex = 0; closureIndex < closures.length; closureIndex++)
            rows.push(closures[closureIndex])
    }
    var index = {}
    for (var rowIndex = 0; rowIndex < rows.length; rowIndex++) {
        var row = rows[rowIndex]
        var date = String(row.date || "")
        if (!/^\d{4}-\d{2}-\d{2}$/.test(date)) continue
        if (!index[date]) index[date] = []
        index[date].push(row)
    }
    return index
}

function markerClasses(holidays) {
    var rows = holidays || []
    var order = ["national", "regional", "bank-closure"]
    var present = {}
    for (var i = 0; i < rows.length; i++) {
        if (rows[i].type === "bank-closure") present["bank-closure"] = true
        else if (rows[i].scope === "regional") present.regional = true
        else if (rows[i].scope === "national") present.national = true
    }
    var output = []
    for (var j = 0; j < order.length; j++)
        if (present[order[j]]) output.push(order[j])
    return output
}
