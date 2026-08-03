import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: service

    property bool startupReady: false
    property bool panelVisible: false
    property string selectedTool: "codex"
    property bool initialized: false
    property bool collectorRunning: collectorProcess.running
    property bool initialRefreshStarted: false
    property string lastRefreshStartedAt: ""
    property string statePath: Quickshell.env("XDG_STATE_HOME")
        ? Quickshell.env("XDG_STATE_HOME") + "/quickshell-astra/ai-usage.json"
        : Quickshell.env("HOME") + "/.local/state/quickshell-astra/ai-usage.json"
    readonly property string collectorPath: {
        var value = String(Qt.resolvedUrl("../../../scripts/ai-usage-collector"))
        return value.indexOf("file://") === 0 ? value.substring(7) : value
    }
    property var providerData: ({
        codex: emptyProvider("codex"),
        claude: emptyProvider("claude"),
        opencode: emptyProvider("opencode")
    })
    property int aiClockTick: 0
    property real lastCollectorKickMs: 0

    function emptyProvider(name) {
        return {
            provider: name,
            status: "never-collected",
            executableFound: false,
            authenticated: null,
            collectedAt: "",
            source: null,
            errorCode: "collector-never-ran",
            message: "Collector has never run",
            windows: [],
            details: {},
            lastSuccess: null
        }
    }

    function provider(name) {
        var value = providerData && providerData[name]
        return value && typeof value === "object" ? value : emptyProvider(name)
    }

    function windowFor(name, duration) {
        var windows = provider(name).windows
        if (!(windows instanceof Array)) return null
        for (var i = 0; i < windows.length; i++) {
            if (parseInt(windows[i].durationMinutes) === duration) return windows[i]
        }
        return null
    }

    function lastSuccess(name) {
        var value = provider(name).lastSuccess
        return value && typeof value === "object" ? value : null
    }

    function epochSeconds(value) {
        if (typeof value === "number") return value > 10000000000 ? value / 1000 : value
        var parsed = Date.parse(String(value || ""))
        return isNaN(parsed) ? 0 : parsed / 1000
    }

    function isStale(name) {
        var value = provider(name)
        if (value.status !== "ok") return value.lastSuccess !== null
        var collected = epochSeconds(value.collectedAt)
        return collected <= 0 || Date.now() / 1000 - collected > staleAfterSeconds
    }

    function pct(name, duration, remaining) {
        var window = windowFor(name, duration)
        if (!window) return 0
        var value = parseFloat(remaining ? window.remainingPercent : window.usedPercent)
        return Math.max(0, Math.min(100, Math.round(isNaN(value) ? 0 : value)))
    }

    function message(name) {
        var value = provider(name)
        if (value.status === "ok" && isStale(name)) return "Cached data is stale"
        return String(value.message || "")
    }

    readonly property int staleAfterSeconds: 900
    readonly property string aiClStatus: provider("claude").status
    readonly property string aiCxStatus: provider("codex").status
    readonly property string aiOcStatus: provider("opencode").status
    readonly property string aiClMessage: message("claude")
    readonly property string aiCxMessage: message("codex")
    readonly property string aiOcMessage: message("opencode")
    readonly property string aiClCollectedAt: String(provider("claude").collectedAt || "")
    readonly property string aiCxCollectedAt: String(provider("codex").collectedAt || "")
    readonly property string aiOcCollectedAt: String(provider("opencode").collectedAt || "")
    readonly property string aiClSource: String(provider("claude").source || "")
    readonly property string aiCxSource: String(provider("codex").source || "")
    readonly property string aiOcSource: String(provider("opencode").source || "")

    readonly property bool aiClFresh: aiClStatus === "ok" && !isStale("claude")
    readonly property bool aiCxFresh: aiCxStatus === "ok" && !isStale("codex")
    readonly property bool aiOcFresh: aiOcStatus === "ok" && !isStale("opencode")
    readonly property bool aiClHas: aiClFresh && provider("claude").windows.length > 0
    readonly property bool aiCxHas: aiCxFresh && provider("codex").windows.length > 0
    readonly property bool aiOcHas: aiOcFresh && provider("opencode").windows.length > 0
    readonly property bool aiCxHas5h: windowFor("codex", 300) !== null
    readonly property bool aiCxHasWeekly: windowFor("codex", 10080) !== null
    readonly property string aiCxState: isStale("codex") ? "stale" : aiCxStatus
    readonly property int aiClPct5h: pct("claude", 300, false)
    readonly property int aiClPct7d: pct("claude", 10080, false)
    readonly property int aiCxPct5h: pct("codex", 300, false)
    readonly property int aiCxPct7d: pct("codex", 10080, false)
    readonly property int aiOcPct5h: pct("opencode", 300, false)
    readonly property int aiOcPct7d: pct("opencode", 10080, false)
    readonly property int aiClReset5hTs: epochSeconds((windowFor("claude", 300) || {}).resetsAt)
    readonly property int aiClReset7dTs: epochSeconds((windowFor("claude", 10080) || {}).resetsAt)
    readonly property int aiCxReset5hTs: epochSeconds((windowFor("codex", 300) || {}).resetsAt)
    readonly property int aiCxReset7dTs: epochSeconds((windowFor("codex", 10080) || {}).resetsAt)
    readonly property bool aiClBlocked: aiClPct5h >= 100
    readonly property string aiCxPlan: String((provider("codex").details || {}).plan || "")
    readonly property bool aiCxCreditsAvailable: (provider("codex").details || {}).creditsAvailable === true
    readonly property string aiCxCredits: String((provider("codex").details || {}).creditsRemaining || "")
    readonly property string aiOcPlan: String((provider("opencode").details || {}).plan || "")
    readonly property string aiOcModel: String((provider("opencode").details || {}).model || "")
    readonly property var aiOcModels: (provider("opencode").details || {}).models || []
    readonly property int aiOcToday: parseInt((provider("opencode").details || {}).tokensToday) || 0
    readonly property int aiClToday: 0
    readonly property int aiCxToday: 0
    readonly property string aiClTokens: ""
    readonly property string aiClRate: ""
    readonly property string aiCxTokens: ""
    readonly property string aiCxRate: ""
    readonly property string aiOcTokens: {
        var details = provider("opencode").details || {}
        var used = parseInt(details.tokens5h) || 0
        var limit = parseInt(details.limit5h) || 0
        return used > 0 && limit > 0 ? (used / 1e6).toFixed(2) + "M / " + (limit / 1e6).toFixed(1) + "M" : ""
    }
    readonly property string aiOcRate: ""

    function diagnosticObject() {
        var result = {
            initialized: initialized,
            collectorRunning: collectorRunning,
            lastRefreshStartedAt: lastRefreshStartedAt,
            providers: {}
        }
        var names = ["codex", "claude", "opencode"]
        for (var i = 0; i < names.length; i++) {
            var name = names[i], value = provider(name)
            result.providers[name] = {
                status: value.status,
                executableFound: value.executableFound === true,
                cacheReadable: initialized,
                collectedAt: value.collectedAt || null,
                isStale: isStale(name),
                errorCode: value.errorCode || null,
                source: value.source || null
            }
        }
        return result
    }

    function reloadState() {
        stateFile.reload()
    }

    function refresh(selectedOnly, force) {
        if (!startupReady || collectorProcess.running) return false
        var now = Date.now()
        var minimumGap = force === true ? 1000 : (panelVisible ? 15000 : 60000)
        if (now - lastCollectorKickMs < minimumGap) return false
        lastCollectorKickMs = now
        lastRefreshStartedAt = new Date(now).toISOString()
        var command = [collectorPath]
        if (selectedOnly === true) command.push("--provider", selectedTool)
        collectorProcess.command = command
        collectorProcess.running = true
        return true
    }

    function refreshAiUsage(selectedOnly, skipBackendKick) {
        aiClockTick++
        if (skipBackendKick !== true) refresh(selectedOnly === true, false)
        reloadState()
    }

    onStartupReadyChanged: {
        if (startupReady && !initialRefreshStarted) {
            initialRefreshStarted = true
            startupTimer.restart()
        }
    }

    property FileView stateFile: FileView {
        path: service.statePath
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try {
                var parsed = JSON.parse(text())
                if (parsed.schemaVersion !== 1 || typeof parsed.providers !== "object")
                    throw new Error("unsupported AI usage state")
                service.providerData = parsed.providers
                service.lastRefreshStartedAt = String(parsed.lastRefreshStartedAt || "")
                service.initialized = true
                service.aiClockTick++
            } catch (error) {
                service.initialized = false
            }
        }
    }

    property Process collectorProcess: Process {
        onExited: reloadTimer.restart()
    }

    property Timer reloadTimer: Timer {
        interval: 250
        repeat: false
        onTriggered: service.reloadState()
    }

    property Timer startupTimer: Timer {
        interval: 1200
        repeat: false
        onTriggered: service.refresh(false, true)
    }

    property Timer periodicTimer: Timer {
        interval: service.panelVisible ? 60000 : 300000
        running: service.startupReady
        repeat: true
        onTriggered: service.refresh(false, false)
    }

    property Timer clockTimer: Timer {
        interval: 60000
        running: service.startupReady
        repeat: true
        onTriggered: service.aiClockTick++
    }
}
