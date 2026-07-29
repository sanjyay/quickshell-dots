function normalizeCode(value, pattern) {
    var code = String(value || "").trim().toUpperCase()
    return pattern.test(code) ? code : ""
}

function defaults(config) {
    var value = config || {}
    var country = normalizeCode(value.country, /^[A-Z]{2}$/)
    var mode = String(value.countryMode || "").toLowerCase()
    if (mode !== "manual" && country) mode = "manual"
    return {
        countryMode: mode === "manual" ? "manual" : "auto",
        country: country,
        subdivision: normalizeCode(value.subdivision, /^[A-Z0-9-]{1,12}$/),
        showNational: value.showNational !== false,
        showRegional: value.showRegional !== false,
        regionalExplicit: value.regionalExplicit === true
    }
}

function restore(value, fallback) {
    if (!value || (value.schemaVersion !== 1 && value.schemaVersion !== 2))
        return defaults(fallback)
    var subdivision = normalizeCode(value.subdivision, /^[A-Z0-9-]{1,12}$/)
    var migrated = value.schemaVersion === 1
    return {
        countryMode: value.countryMode === "manual" ? "manual" : "auto",
        country: normalizeCode(value.country, /^[A-Z]{2}$/),
        subdivision: subdivision,
        showNational: value.showNational !== false,
        showRegional: migrated && subdivision ? true : value.showRegional !== false,
        regionalExplicit: migrated ? false : value.regionalExplicit === true
    }
}

function selectCountry(state, code) {
    var next = restore({ schemaVersion: 2,
        countryMode: state.countryMode,
        country: state.country,
        subdivision: state.subdivision,
        showNational: state.showNational,
        showRegional: state.showRegional,
        regionalExplicit: state.regionalExplicit
    }, {})
    next.countryMode = "manual"
    next.country = normalizeCode(code, /^[A-Z]{2}$/)
    next.subdivision = ""
    return next
}

function useAutomatic(state, preserveSubdivision) {
    var subdivision = preserveSubdivision ? state.subdivision : ""
    var next = selectCountry(state, "")
    next.countryMode = "auto"
    next.subdivision = subdivision
    return next
}

function selectSubdivision(state, code) {
    var next = restore({ schemaVersion: 2,
        countryMode: state.countryMode,
        country: state.country,
        subdivision: state.subdivision,
        showNational: state.showNational,
        showRegional: state.showRegional,
        regionalExplicit: state.regionalExplicit
    }, {})
    next.subdivision = normalizeCode(code, /^[A-Z0-9-]{1,12}$/)
    if (next.subdivision) {
        next.showRegional = true
        next.regionalExplicit = false
    }
    return next
}

function setCategories(state, national, regional) {
    var next = restore({
        schemaVersion: 2,
        countryMode: state.countryMode,
        country: state.country,
        subdivision: state.subdivision,
        showNational: state.showNational,
        showRegional: state.showRegional,
        regionalExplicit: state.regionalExplicit
    }, {})
    next.showNational = national
    next.showRegional = regional
    next.regionalExplicit = true
    return next
}

function effectiveCountry(state, detectedCode, supportedCodes) {
    var codes = supportedCodes || []
    var selected = state.countryMode === "manual" ? state.country : detectedCode
    return codes.indexOf(selected) >= 0 ? selected : ""
}

function effectiveSubdivision(state, supportedCodes) {
    var codes = supportedCodes || []
    return codes.indexOf(state.subdivision) >= 0 ? state.subdivision : ""
}
