import QtQuick
import Quickshell
import Quickshell.Io
import "../modules"
import "HolidaySelection.js" as HolidaySelection
import "HolidayCalendarModel.js" as HolidayCalendarModel

QtObject {
    id: service

    property bool enabled: true
    property bool showInGrid: true
    property bool panelVisible: false
    property int displayedYear: 0

    property string defaultCountryMode: "auto"
    property string defaultCountry: ""
    property string defaultSubdivision: ""
    property bool defaultShowNational: true
    property bool defaultShowRegional: true
    property bool defaultRegionalExplicit: false

    property bool stateLoaded: false
    property bool migrationPending: false
    property string countrySelectionMode: "auto"
    property string configuredCountryCode: ""
    property string configuredSubdivisionCode: ""
    property bool showNational: true
    property bool showRegional: true
    property bool regionalExplicit: false

    property string detectionStatus: "loading"
    property string detectionMessage: "Detecting country from system timezone"
    property string detectedCountryCode: ""
    property string detectedCountryName: ""
    property string timezone: ""

    property var countries: []
    property var subdivisions: []
    property string countryStatus: "idle"
    property string subdivisionStatus: "idle"
    property string status: enabled ? "idle" : "disabled"
    property string errorCode: ""
    property string errorMessage: ""
    property string selectionWarning: ""
    property var holidaysByDate: ({})
    property string activeProviderId: ""
    property string activeProviderKind: ""
    property var activeProviderSource: ({})

    property string holidayActiveKey: ""
    property string holidayOutput: ""
    property bool holidayQueued: false
    property string subdivisionActiveCountry: ""
    property string subdivisionOutput: ""
    property bool subdivisionQueued: false
    property string countryOutput: ""
    property int countryRequestToken: 0
    property int countryActiveToken: 0
    property bool countryQueued: false

    readonly property string statePath: Quickshell.env("XDG_STATE_HOME")
        ? Quickshell.env("XDG_STATE_HOME") + "/quickshell-astra/holiday-settings.json"
        : Quickshell.env("HOME") + "/.local/state/quickshell-astra/holiday-settings.json"
    readonly property string helperPath: {
        var value = String(Qt.resolvedUrl("../../../scripts/holiday-helper.js"))
        return value.indexOf("file://") === 0 ? value.substring(7) : value
    }
    readonly property bool configuredCountryValid: countrySelectionMode === "manual"
        && countryEntry(configuredCountryCode) !== null
    readonly property string effectiveCountryCode: countrySelectionMode === "manual"
        ? (configuredCountryValid ? configuredCountryCode : "")
        : detectedCountryCode
    readonly property string effectiveCountryName: {
        var entry = countryEntry(effectiveCountryCode)
        return entry ? entry.name : ""
    }
    readonly property string effectiveSubdivisionCode: subdivisionEntry(configuredSubdivisionCode)
        ? configuredSubdivisionCode : ""
    readonly property string effectiveSubdivisionName: {
        var entry = subdivisionEntry(effectiveSubdivisionCode)
        return entry ? entry.name : ""
    }
    readonly property bool hasSubdivisions: subdivisions.length > 0

    function countryEntry(code) {
        var wanted = String(code || "").toUpperCase()
        for (var i = 0; i < countries.length; i++)
            if (countries[i].code === wanted) return countries[i]
        return null
    }

    function subdivisionEntry(code) {
        var wanted = String(code || "").toUpperCase()
        if (!wanted) return null
        for (var i = 0; i < subdivisions.length; i++)
            if (subdivisions[i].code === wanted) return subdivisions[i]
        return null
    }

    function filteredCountries(query) {
        var needle = String(query || "").trim().toLocaleLowerCase()
        if (!needle) return countries
        var output = []
        for (var i = 0; i < countries.length; i++) {
            var entry = countries[i]
            if (entry.code.toLocaleLowerCase().indexOf(needle) >= 0 ||
                entry.name.toLocaleLowerCase().indexOf(needle) >= 0)
                output.push(entry)
        }
        return output
    }

    function filteredSubdivisions(query) {
        var needle = String(query || "").trim().toLocaleLowerCase()
        if (!needle) return subdivisions
        var output = []
        for (var i = 0; i < subdivisions.length; i++) {
            var entry = subdivisions[i]
            if (entry.code.toLocaleLowerCase().indexOf(needle) >= 0 ||
                entry.name.toLocaleLowerCase().indexOf(needle) >= 0)
                output.push(entry)
        }
        return output
    }

    function applyDefaults() {
        applySelection(HolidaySelection.defaults({
            countryMode: defaultCountryMode,
            country: defaultCountry,
            subdivision: defaultSubdivision,
            showNational: defaultShowNational,
            showRegional: defaultShowRegional,
            regionalExplicit: defaultRegionalExplicit
        }))
    }

    function applyPersisted(value) {
        if (!value || (value.schemaVersion !== 1 && value.schemaVersion !== 2))
            throw new Error("unsupported holiday settings")
        applySelection(HolidaySelection.restore(value, {}))
        migrationPending = value.schemaVersion === 1
    }

    function applySelection(value) {
        countrySelectionMode = value.countryMode
        configuredCountryCode = value.country
        configuredSubdivisionCode = value.subdivision
        showNational = value.showNational
        showRegional = value.showRegional
        regionalExplicit = value.regionalExplicit
    }

    function selectionObject() {
        return {
            countryMode: countrySelectionMode,
            country: configuredCountryCode,
            subdivision: configuredSubdivisionCode,
            showNational: showNational,
            showRegional: showRegional,
            regionalExplicit: regionalExplicit
        }
    }

    function finishStateLoad() {
        if (stateLoaded) return
        stateLoaded = true
        if (migrationPending) {
            migrationPending = false
            persist()
        }
        if (panelVisible) requestCountries()
        scheduleRefresh()
    }

    function persist() {
        if (!stateLoaded) return
        settingsWriter.write(JSON.stringify({
            schemaVersion: 2,
            countryMode: countrySelectionMode,
            country: configuredCountryCode,
            subdivision: configuredSubdivisionCode,
            showNational: showNational,
            showRegional: showRegional,
            regionalExplicit: regionalExplicit,
            showInGrid: showInGrid
        }))
    }

    function selectCountry(code) {
        var entry = countryEntry(code)
        if (!entry) return false
        applySelection(HolidaySelection.selectCountry(selectionObject(), entry.code))
        subdivisions = []
        selectionWarning = ""
        persist()
        requestSubdivisions()
        scheduleRefresh()
        return true
    }

    function useDetectedCountry() {
        var preserveSubdivision = detectedCountryCode !== ""
            && detectedCountryCode === effectiveCountryCode
            && subdivisionEntry(configuredSubdivisionCode) !== null
        applySelection(HolidaySelection.useAutomatic(selectionObject(), preserveSubdivision))
        if (!preserveSubdivision) subdivisions = []
        selectionWarning = ""
        persist()
        requestSubdivisions()
        scheduleRefresh()
    }

    function selectSubdivision(code) {
        var value = String(code || "").toUpperCase()
        if (value && !subdivisionEntry(value)) return false
        applySelection(HolidaySelection.selectSubdivision(selectionObject(), value))
        selectionWarning = ""
        persist()
        scheduleRefresh()
        return true
    }

    function setCategories(national, regional) {
        applySelection(HolidaySelection.setCategories(selectionObject(), national, regional))
        persist()
        scheduleRefresh()
    }

    function desiredHolidayKey() {
        return [effectiveCountryCode, effectiveSubdivisionCode, displayedYear,
                showNational ? "1" : "0", showRegional ? "1" : "0"].join("|")
    }

    function clearHolidayModel() {
        holidaysByDate = ({})
        activeProviderId = ""
        activeProviderKind = ""
        activeProviderSource = ({})
    }

    function requestCountries() {
        if (!enabled) return
        countryRequestToken++
        if (countryProcess.running) {
            countryQueued = true
            return
        }
        countryQueued = false
        countryActiveToken = countryRequestToken
        countryOutput = ""
        countryStatus = "loading"
        countryProcess.command = ["node", helperPath, "countries"]
        countryProcess.running = true
    }

    function acceptCountries(exitCode, token) {
        if (token !== countryRequestToken) {
            if (countryQueued) requestCountries()
            return
        }
        try {
            var payload = JSON.parse(countryOutput)
            if (exitCode !== 0 || payload.ok !== true || !(payload.countries instanceof Array))
                throw payload.error || { code: "country-list-failed", message: "country list unavailable" }
            countries = payload.countries
            var detection = payload.detection || {}
            detectionStatus = String(detection.status || "unresolved")
            detectedCountryCode = detectionStatus === "ok" ? String(detection.country || "") : ""
            var detected = countryEntry(detectedCountryCode)
            detectedCountryName = detected ? detected.name : ""
            timezone = String(detection.timezone || "")
            detectionMessage = detectionStatus === "ok"
                ? "Detected from timezone: " + detectedCountryName
                : (detectionStatus === "ambiguous"
                    ? "Timezone maps to multiple countries"
                    : "Timezone country could not be detected")
            countryStatus = "ready"
            validateSelection()
            requestSubdivisions()
            scheduleRefresh()
        } catch (error) {
            countries = []
            countryStatus = "error"
            detectionStatus = "unresolved"
            detectionMessage = "Country metadata unavailable"
            setError(error, "country-list-failed")
        }
        if (countryQueued) requestCountries()
    }

    function validateSelection() {
        selectionWarning = ""
        if (countrySelectionMode === "manual" && !configuredCountryValid) {
            selectionWarning = configuredCountryCode
                ? "Saved country " + configuredCountryCode + " is unsupported"
                : "Select a holiday country"
        } else if (countrySelectionMode === "auto" && !detectedCountryCode) {
            selectionWarning = "Automatic country detection needs a manual selection"
        }
    }

    function requestSubdivisions() {
        if (!enabled || !effectiveCountryCode) {
            subdivisions = []
            subdivisionStatus = "idle"
            return
        }
        subdivisionQueued = true
        if (!subdivisionProcess.running) Qt.callLater(startSubdivisionRequest)
    }

    function startSubdivisionRequest() {
        if (!subdivisionQueued || subdivisionProcess.running || !effectiveCountryCode) return
        subdivisionQueued = false
        subdivisionActiveCountry = effectiveCountryCode
        subdivisionOutput = ""
        subdivisionStatus = "loading"
        subdivisionProcess.command = ["node", helperPath, "subdivisions", subdivisionActiveCountry]
        subdivisionProcess.running = true
    }

    function acceptSubdivisions(exitCode) {
        var requestedCountry = subdivisionActiveCountry
        if (requestedCountry !== effectiveCountryCode) {
            requestSubdivisions()
            return
        }
        try {
            var payload = JSON.parse(subdivisionOutput)
            if (exitCode !== 0 || payload.ok !== true ||
                payload.countryCode !== requestedCountry || !(payload.subdivisions instanceof Array))
                throw payload.error || { code: "subdivision-list-failed", message: "subdivision list unavailable" }
            subdivisions = payload.subdivisions
            subdivisionStatus = "ready"
            if (configuredSubdivisionCode && !subdivisionEntry(configuredSubdivisionCode))
                selectionWarning = "Saved region " + configuredSubdivisionCode + " is unsupported for "
                    + effectiveCountryName
            else validateSelection()
            scheduleRefresh()
        } catch (error) {
            subdivisions = []
            subdivisionStatus = "error"
            setError(error, "subdivision-list-failed")
        }
        if (subdivisionQueued) requestSubdivisions()
    }

    function scheduleRefresh() {
        if (!enabled) {
            holidayQueued = false
            status = "disabled"
            errorCode = ""
            errorMessage = ""
            clearHolidayModel()
            if (holidayProcess.running) holidayProcess.running = false
            return
        }
        if (!stateLoaded || !panelVisible || displayedYear < 1900) return
        if (countryStatus !== "ready") {
            requestCountries()
            return
        }
        if (!effectiveCountryCode) {
            clearHolidayModel()
            status = "error"
            errorCode = "country-unresolved"
            errorMessage = selectionWarning
            return
        }
        holidayQueued = true
        if (!holidayProcess.running) Qt.callLater(startHolidayRequest)
    }

    function startHolidayRequest() {
        if (!holidayQueued || holidayProcess.running || !enabled || !panelVisible) return
        holidayQueued = false
        holidayActiveKey = desiredHolidayKey()
        holidayOutput = ""
        status = "loading"
        errorCode = ""
        errorMessage = ""
        holidayProcess.command = [
            "node", helperPath, "get",
            "--country", effectiveCountryCode,
            "--year", String(displayedYear),
            "--subdivision", effectiveSubdivisionCode,
            "--show-national", showNational ? "true" : "false",
            "--show-regional", showRegional ? "true" : "false"
        ]
        holidayProcess.running = true
    }

    function acceptHolidays(exitCode) {
        var requestKey = holidayActiveKey
        if (requestKey !== desiredHolidayKey() || !enabled) {
            scheduleRefresh()
            return
        }
        try {
            var payload = JSON.parse(holidayOutput)
            if (exitCode !== 0 || payload.ok !== true || !(payload.holidays instanceof Array))
                throw payload.error || { code: "helper-failed", message: "holiday helper failed" }
            activeProviderId = String(payload.provider && payload.provider.id || "")
            activeProviderKind = String(payload.provider && payload.provider.kind || "")
            activeProviderSource = payload.provider && payload.provider.source
                ? payload.provider.source : ({})
            var index = {}
            for (var i = 0; i < payload.holidays.length; i++) {
                var holiday = payload.holidays[i]
                var date = String(holiday.date || "")
                var scope = String(holiday.scope || "")
                if (!/^\d{4}-\d{2}-\d{2}$/.test(date) ||
                    ["national", "regional"].indexOf(scope) < 0 ||
                    String(holiday.type || "") !== "public") continue
                var normalized = {
                    date: date,
                    name: String(holiday.name || ""),
                    type: String(holiday.type || "public"),
                    scope: scope,
                    countryCode: String(holiday.countryCode || ""),
                    countryName: String(holiday.countryName || ""),
                    subdivisionCode: String(holiday.subdivisionCode || ""),
                    subdivisionName: String(holiday.subdivisionName || ""),
                    substitute: holiday.substitute === true,
                    source: String(holiday.source || "")
                }
                if (!index[date]) index[date] = []
                index[date].push(normalized)
            }
            appendIndianBankClosures(index)
            holidaysByDate = index
            status = "ready"
            errorCode = ""
            errorMessage = ""
        } catch (error) {
            var fallbackIndex = {}
            appendIndianBankClosures(fallbackIndex)
            holidaysByDate = fallbackIndex
            activeProviderId = ""
            activeProviderKind = ""
            activeProviderSource = ({})
            status = "error"
            setError(error, "malformed-json")
        }
        if (holidayQueued || requestKey !== desiredHolidayKey()) scheduleRefresh()
    }

    function setError(error, fallbackCode) {
        errorCode = String(error.code || fallbackCode)
        errorMessage = String(error.message || "Holiday data unavailable")
        console.warn("Quickshell Astra holidays: " + errorCode + ": " + errorMessage)
    }

    function holidaysFor(date) {
        return holidaysByDate[date] || []
    }

    function markerClassesFor(date) {
        var rows = holidaysFor(date)
        var national = false
        var regional = false
        var bankClosure = false
        for (var i = 0; i < rows.length; i++) {
            if (rows[i].type === "bank-closure") bankClosure = true
            else if (rows[i].scope === "regional") regional = true
            else if (rows[i].scope === "national") national = true
        }
        var markers = []
        if (national) markers.push("national")
        if (regional) markers.push("regional")
        if (bankClosure) markers.push("bank-closure")
        return markers
    }

    function appendIndianBankClosures(index) {
        if (effectiveCountryCode === "IN") {
            var closures = HolidayCalendarModel.indianBankClosures(displayedYear)
            for (var closureIndex = 0; closureIndex < closures.length; closureIndex++) {
                var closure = closures[closureIndex]
                if (!index[closure.date]) index[closure.date] = []
                index[closure.date].push(closure)
            }
        }
    }

    onPanelVisibleChanged: {
        if (panelVisible) requestCountries()
    }
    onDisplayedYearChanged: { clearHolidayModel(); scheduleRefresh() }
    onEnabledChanged: scheduleRefresh()

    property FileView stateFile: FileView {
        path: service.statePath
        printErrors: false
        onLoaded: {
            try {
                service.applyPersisted(JSON.parse(text()))
            } catch (error) {
                service.applyDefaults()
                service.selectionWarning = "Saved holiday settings were invalid; configuration defaults are active"
            }
            service.finishStateLoad()
        }
        onLoadFailed: {
            service.applyDefaults()
            service.finishStateLoad()
        }
    }

    property AtomicStateWriter settingsWriter: AtomicStateWriter {
        path: service.statePath
        validateJson: true
        writerCommand: ["node", service.helperPath, "state-write"]
        onSaved: service.stateFile.reload()
        onFailed: function(state, exitCode) {
            console.warn("Quickshell Astra holidays: settings write failed with exit code " + exitCode)
        }
    }

    property Process countryProcess: Process {
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: service.countryOutput = text
        }
        onExited: function(exitCode) {
            service.acceptCountries(exitCode, service.countryActiveToken)
        }
    }

    property Process subdivisionProcess: Process {
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: service.subdivisionOutput = text
        }
        onExited: function(exitCode) { service.acceptSubdivisions(exitCode) }
    }

    property Process holidayProcess: Process {
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: service.holidayOutput = text
        }
        onExited: function(exitCode) { service.acceptHolidays(exitCode) }
    }

    property Timer detectionRefreshTimer: Timer {
        interval: 60000
        repeat: true
        running: service.panelVisible && service.countrySelectionMode === "auto"
        onTriggered: service.requestCountries()
    }

    Component.onCompleted: stateFile.reload()
}
