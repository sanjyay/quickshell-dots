import QtQuick
import Quickshell.Io

QtObject {
    id: service

    property bool panelVisible: false
    property string selectedTool: "codex"


    // ── AI usage data (single source of truth) ───────────────────
    // The bar pill (ClaudeWidget) and the AiUsagePanel both render from these —
    // the cache parsing lives ONLY here so the two views can never drift apart.
    // Token strings are bare "X.XXM / Y.YM"; the pill tooltip appends " tokens".
    property bool   aiClHas: false
    property bool   aiClFresh: false
    property int    aiClPct5h: 0
    property int    aiClPct7d: 0
    property bool   aiClBlocked: false
    property string aiClTokens: ""
    property string aiClRate: ""
    property int    aiClReset5hTs: 0
    property int    aiClReset7dTs: 0
    property int    aiClToday: 0

    property bool   aiCxHas: false
    property bool   aiCxFresh: false
    property string aiCxState: "stale"
    property bool   aiCxHas5h: false
    property bool   aiCxHasWeekly: false
    property int    aiCxPct5h: 0
    property int    aiCxPct7d: 0
    property string aiCxPlan: ""
    property bool   aiCxCreditsAvailable: false
    property string aiCxCredits: ""
    property string aiCxTokens: ""
    property string aiCxRate: ""
    property int    aiCxReset5hTs: 0
    property int    aiCxReset7dTs: 0
    property int    aiCxToday: 0

    property bool   aiOcHas: false
    property bool   aiOcFresh: false
    property int    aiOcPct5h: 0
    property int    aiOcPct7d: 0
    property string aiOcPlan: ""
    property string aiOcTokens: ""
    property string aiOcRate: ""
    property string aiOcModel: ""
    property int    aiOcToday: 0
    property var    aiOcModels: []
    property int    aiClockTick: 0
    property real   aiLastBackendKick: 0

    // F15: clamp an external 0..1 utilization to a 0–100 int (a negative/over-range value would
    // otherwise produce wrong text and negative/overwide usage bars)
    function aiPct(v) { return Math.max(0, Math.min(100, Math.round((parseFloat(v) || 0) * 100))) }

    function aiFmtReset(ts) {
        aiClockTick
        var now = Date.now() / 1000
        if (!(ts > now)) return ""
        var mins = Math.round((ts - now) / 60)
        if (mins < 60) return mins + "m"
        var h = Math.floor(mins / 60), m = mins % 60
        if (h < 24) return h + "h " + m + "m"
        var d = Math.floor(h / 24); return d + "d " + (h % 24) + "h"
    }

    function aiFmtResetAt(ts) {
        if (!(ts > 0)) return ""
        return new Date(ts * 1000).toLocaleString(Qt.locale(), "MMM d, yyyy h:mm AP")
    }

    Process {
        id: aiReadClaude
        command: ["bash", "-c",
            "f=\"$HOME/.cache/claude-usage.json\"; stat -c %Y \"$f\" 2>/dev/null; cat \"$f\" 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                var raw = this.text, nl = raw.indexOf("\n")
                var mtime = nl > 0 ? (parseInt(raw.substring(0, nl)) || 0) : 0
                var ageOk = mtime > 0 && (Date.now() / 1000 - mtime) < 900
                try {
                    var d = JSON.parse((nl > 0 ? raw.substring(nl + 1) : "").trim())
                    service.aiClHas = true
                    service.aiClFresh = ageOk && d._source !== "stale"
                    service.aiClPct5h = service.aiPct(d["5h-utilization"])
                    service.aiClPct7d = service.aiPct(d["7d-utilization"])
                    service.aiClBlocked = d.status === "rejected" || d.status === "blocked"
                    service.aiClReset5hTs = parseInt(d["5h-reset"]) || 0
                    service.aiClReset7dTs = parseInt(d["7d-reset"]) || 0
                    var used = (d["_tokens_used"] || 0), lim = (d["_window_limit"] || 0)
                    service.aiClTokens = used ? (used / 1e6).toFixed(2) + "M / " + (lim / 1e6).toFixed(1) + "M" : ""
                    var rateH = Math.round((d["_rate_per_hour"] || 0) / 1000)
                    service.aiClRate = rateH > 0 ? rateH + "k tok/h" : ""
                    service.aiClToday = parseInt(d._today_tokens) || 0
                } catch (e) {
                    service.aiClHas = false; service.aiClFresh = false
                    service.aiClPct5h = 0; service.aiClPct7d = 0
                    service.aiClBlocked = false; service.aiClTokens = ""; service.aiClRate = ""
                    service.aiClReset5hTs = 0; service.aiClReset7dTs = 0; service.aiClToday = 0
                }
            }
        }
    }

    Process {
        id: aiReadCodex
        command: ["bash", "-c",
            "f=\"$HOME/.cache/codex-usage.json\"; stat -c %Y \"$f\" 2>/dev/null; cat \"$f\" 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                var raw = this.text, nl = raw.indexOf("\n")
                var mtime = nl > 0 ? (parseInt(raw.substring(0, nl)) || 0) : 0
                var ageOk = mtime > 0 && (Date.now() / 1000 - mtime) < 900
                try {
                    var d = JSON.parse((nl > 0 ? raw.substring(nl + 1) : "").trim())
                    service.aiCxHas5h = d["5h-available"] === true
                    service.aiCxHasWeekly = d["7d-available"] === true
                    service.aiCxCreditsAvailable = d["credits-available"] === true
                    service.aiCxHas = service.aiCxHas5h || service.aiCxHasWeekly || service.aiCxCreditsAvailable
                    service.aiCxState = !ageOk || d._source === "stale" ? "stale"
                        : (d._source === "rpc" ? "live" : "cached")
                    service.aiCxFresh = service.aiCxState === "live"
                    service.aiCxPct5h = service.aiPct(d["5h-utilization"])
                    service.aiCxPct7d = service.aiPct(d["7d-utilization"])
                    service.aiCxReset5hTs = parseInt(d["5h-reset"]) || 0
                    service.aiCxReset7dTs = parseInt(d["7d-reset"]) || 0
                    service.aiCxPlan = d._plan || ""
                    service.aiCxCredits = service.aiCxCreditsAvailable ? String(d["credits-remaining"]) : ""
                    var cxUsed = (d["_tokens_used"] || 0), cxLim = (d["_window_limit"] || 0)
                    service.aiCxTokens = cxUsed ? (cxUsed / 1e6).toFixed(2) + "M / " + (cxLim / 1e6).toFixed(1) + "M" : ""
                    var cxRateH = Math.round((d["_rate_per_hour"] || 0) / 1000)
                    service.aiCxRate = cxRateH > 0 ? cxRateH + "k tok/h" : ""
                    service.aiCxToday = parseInt(d._today_tokens) || 0
                } catch (e) {
                    service.aiCxHas = false; service.aiCxFresh = false
                    service.aiCxState = "stale"; service.aiCxHas5h = false; service.aiCxHasWeekly = false
                    service.aiCxPct5h = 0; service.aiCxPct7d = 0
                    service.aiCxPlan = ""; service.aiCxCreditsAvailable = false; service.aiCxCredits = ""
                    service.aiCxTokens = ""; service.aiCxRate = ""; service.aiCxToday = 0
                    service.aiCxReset5hTs = 0; service.aiCxReset7dTs = 0
                }
            }
        }
    }

    Process {
        id: aiReadOpenCode
        command: ["bash", "-c",
            "f=\"$HOME/.cache/opencode-usage.json\"; stat -c %Y \"$f\" 2>/dev/null; cat \"$f\" 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                var raw = this.text, nl = raw.indexOf("\n")
                var mtime = nl > 0 ? (parseInt(raw.substring(0, nl)) || 0) : 0
                var ageOk = mtime > 0 && (Date.now() / 1000 - mtime) < 900
                try {
                    var d = JSON.parse((nl > 0 ? raw.substring(nl + 1) : "").trim())
                    service.aiOcHas = true
                    service.aiOcFresh = ageOk && d._source !== "stale"
                    service.aiOcPct5h = service.aiPct(d["5h-utilization"])
                    service.aiOcPct7d = service.aiPct(d["7d-utilization"])
                    service.aiOcPlan = d._plan || ""
                    var ocUsed = (d["_tokens_used"] || 0), ocLim = (d["_window_limit"] || 0)
                    service.aiOcTokens = ocUsed ? (ocUsed / 1e6).toFixed(2) + "M / " + (ocLim / 1e6).toFixed(1) + "M" : ""
                    var ocRateH = Math.round((d["_rate_per_hour"] || 0) / 1000)
                    service.aiOcRate = ocRateH > 0 ? ocRateH + "k tok/h" : ""
                    service.aiOcToday = parseInt(d._today_tokens) || 0
                    service.aiOcModel = d._model || ""
                    service.aiOcModels = d._models instanceof Array ? d._models : []
                } catch (e) {
                    service.aiOcHas = false; service.aiOcFresh = false
                    service.aiOcPct5h = 0; service.aiOcPct7d = 0
                    service.aiOcPlan = ""; service.aiOcTokens = ""; service.aiOcRate = ""; service.aiOcModel = ""
                    service.aiOcToday = 0; service.aiOcModels = []
                }
            }
        }
    }

    Process {
        id: aiRunBackends
        onExited: aiReadAfterBackend.restart()
    }

    Timer {
        id: aiReadAfterBackend
        interval: 600
        repeat: false
        onTriggered: service.refreshAiUsage(true, true)
    }

    function kickAiBackends(selectedOnly) {
        var now = Date.now()
        var minGap = panelVisible ? 15000 : 60000
        if (aiRunBackends.running || now - aiLastBackendKick < minGap) return
        aiLastBackendKick = now

        var names = selectedOnly === true ? [selectedTool] : ["claude", "codex", "opencode"]
        var cmds = []
        for (var i = 0; i < names.length; i++) {
            if (names[i] === "claude")
                cmds.push("[ -x \"$HOME/.local/bin/claude-usage\" ] && \"$HOME/.local/bin/claude-usage\" >/dev/null 2>&1 || true")
            else if (names[i] === "codex")
                cmds.push("[ -x \"$HOME/.local/bin/codex-usage\" ] && \"$HOME/.local/bin/codex-usage\" >/dev/null 2>&1 || true")
            else if (names[i] === "opencode")
                cmds.push("[ -x \"$HOME/.local/bin/opencode-usage\" ] && \"$HOME/.local/bin/opencode-usage\" >/dev/null 2>&1 || true")
        }
        if (cmds.length === 0) return
        aiRunBackends.command = ["bash", "-lc", cmds.join("; ")]
        aiRunBackends.running = false
        aiRunBackends.running = true
    }

    function refreshAiUsage(selectedOnly, skipBackendKick) {
        aiClockTick++
        var only = selectedOnly === true
        if (!only || selectedTool === "claude") {
            aiReadClaude.running = false; aiReadClaude.running = true
        }
        if (!only || selectedTool === "codex") {
            aiReadCodex.running = false;  aiReadCodex.running = true
        }
        if (!only || selectedTool === "opencode") {
            aiReadOpenCode.running = false; aiReadOpenCode.running = true
        }
        if (skipBackendKick !== true) kickAiBackends(only)
    }

    Timer {
        // Systemd timers own scheduled backend refreshes. QML only rereads the
        // caches here; opening the panel remains an explicit immediate refresh.
        interval: service.panelVisible ? 5000 : 15000
        running: true; repeat: true; triggeredOnStart: true
        onTriggered: service.refreshAiUsage(service.panelVisible, true)
    }
}
