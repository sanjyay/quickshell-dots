import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io

// Combined AI-usage pill (Claude Code + OpenAI Codex). The bar shows ONE tool
// (root.aiTool) as a themed-tinted SVG with a bottom-up usage fill; the tooltip
// shows BOTH; clicking opens the AiUsagePanel where the tool can be switched.
// Gating is unchanged: root.modClaude is the on/off toggle for the whole pill.
Item {
    id: rootMod
    required property var root

    // ── which tool the bar pill displays ──
    readonly property bool isCodex: root.aiTool === "codex"

    // ── Claude state ──
    property bool   clActive: false
    property bool   clFresh:  false
    property int    clPct5h:  0
    property int    clPct7d:  0
    property bool   clBlocked: false
    property string clTokens: ""
    property string clRate:   ""
    property int    clReset5hTs: 0
    property bool   clHas: false

    // ── Codex state ──
    property bool   cxActive: false
    property bool   cxFresh:  false
    property int    cxPct5h:  0
    property int    cxPct7d:  0    // weekly
    property string cxPlan:   ""
    property string cxTokens: ""
    property string cxRate:   ""
    property int    cxTodayTok: 0
    property int    cxReset5hTs: 0
    property int    cxReset7dTs: 0
    property bool   cxHas: false

    // ── per-tool signal (active OR fresh non-zero usage) ──
    readonly property bool clSignal: clActive || (clPct5h > 0 && clFresh)
    readonly property bool cxSignal: cxActive || (cxPct5h > 0 && cxFresh)

    // ── selected-tool display values ──
    readonly property int  pct5h:   isCodex ? cxPct5h : clPct5h
    readonly property int  pct5hStep: Math.round(pct5h / 5) * 5
    readonly property bool selFresh: isCodex ? cxFresh : clFresh
    readonly property bool selSignal: isCodex ? cxSignal : clSignal
    readonly property bool blocked:  isCodex ? false : clBlocked

    // show whenever the gate is on AND either tool has a signal — the pill stays
    // reachable (to open the panel + switch) even if the selected tool is idle
    readonly property bool shown: (clSignal || cxSignal) && root.modClaude

    function fmtReset(ts) {
        var now = Date.now() / 1000
        if (!(ts > now)) return ""
        var mins = Math.round((ts - now) / 60)
        if (mins < 60) return mins + "m"
        var h = Math.floor(mins / 60), m = mins % 60
        if (h < 24) return h + "h " + m + "m"
        var d = Math.floor(h / 24); return d + "d " + (h % 24) + "h"
    }

    readonly property string tooltipText: {
        var lines = []
        if (clHas || clActive) {
            lines.push("Claude Code")
            var cr = fmtReset(clReset5hTs)
            lines.push("5h: " + clPct5h + "%" + (cr ? "  (reset in " + cr + ")" : ""))
            if (clPct7d > 0) lines.push("7d: " + clPct7d + "%")
            if (clTokens)    lines.push(clTokens + (clRate ? "  · " + clRate : ""))
        }
        if (cxHas || cxActive) {
            if (lines.length) lines.push("")
            lines.push("OpenAI Codex" + (cxPlan ? "  (" + cxPlan + ")" : ""))
            var x5 = fmtReset(cxReset5hTs)
            lines.push("5h: " + cxPct5h + "%" + (x5 ? "  (reset in " + x5 + ")" : ""))
            var x7 = fmtReset(cxReset7dTs)
            lines.push("7d: " + cxPct7d + "%" + (x7 ? "  (reset in " + x7 + ")" : ""))
            if (cxTokens) lines.push(cxTokens + (cxRate ? "  · " + cxRate : ""))
        }
        return lines.length ? lines.join("\n") : "AI usage"
    }

    // keep rendered until the collapse animation finishes
    visible: implicitWidth > 0.5
    implicitWidth: shown ? row.implicitWidth + 18 : 0
    implicitHeight: 28
    opacity: shown ? 1 : 0

    Behavior on implicitWidth { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
    Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

    // ── process detection ──
    Process {
        id: detectClaude
        command: ["bash", "-c", "pgrep -x claude >/dev/null 2>&1 && echo 1 || echo 0"]
        stdout: StdioCollector { onStreamFinished: { rootMod.clActive = (this.text.trim() === "1") } }
    }
    Process {
        id: detectCodex
        // exact process-name match (comm == "codex") so the cache readers / poller
        // (python codex-usage, bash on codex-usage.json) never count as "active";
        // drop the short-lived `codex … app-server` our own backend spawns
        command: ["bash", "-c", "pgrep -xa codex 2>/dev/null | grep -vq app-server && echo 1 || echo 0"]
        stdout: StdioCollector { onStreamFinished: { rootMod.cxActive = (this.text.trim() === "1") } }
    }
    Timer {
        interval: 5000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: {
            detectClaude.running = false; detectClaude.running = true
            detectCodex.running = false;  detectCodex.running = true
        }
    }

    // ── background pill ──
    Rectangle {
        x: 0; anchors.verticalCenter: parent.verticalCenter
        width: Math.round(row.width) + 18
        height: root.pillH; radius: root.pillRadius
        color: root.pill
        border.color: root.pillBorder
        border.width: root.pillBorderW
        PillShadow { theme: root }
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 5

        // icon with bottom-to-top usage fill. Claude keeps its nerd-font glyph;
        // Codex uses its logo SVG (no glyph exists) themed via the shared logo-tint
        // shader (keeps alpha, recolors to a flat color). Both fill bottom→top.
        Item {
            id: iconItem
            anchors.verticalCenter: parent.verticalCenter
            implicitWidth: 15; implicitHeight: 15

            // ── Claude: nerd-font glyph (original look) ──
            Item {
                anchors.centerIn: parent
                visible: !rootMod.isCodex
                implicitWidth: glyphBase.implicitWidth
                implicitHeight: glyphBase.implicitHeight

                Text {
                    id: glyphBase
                    text: String.fromCodePoint(0xF167A)
                    color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.25)
                    font.family: root.mono
                    font.pixelSize: 14
                }
                Item {
                    clip: true
                    width: parent.width
                    anchors.bottom: parent.bottom
                    height: rootMod.pct5hStep > 0
                        ? Math.min(parent.height, Math.max(parent.height * rootMod.pct5hStep / 100, parent.height * 0.25))
                        : 0
                    Behavior on height { NumberAnimation { duration: 600; easing.type: Easing.OutCubic } }
                    Text {
                        anchors.bottom: parent.bottom
                        text: String.fromCodePoint(0xF167A)
                        color: root.seal
                        font.family: root.mono
                        font.pixelSize: 14
                        Behavior on color { ColorAnimation { duration: 200 } }
                    }
                }
            }

            // ── Codex: tinted SVG ──
            Item {
                anchors.fill: parent
                visible: rootMod.isCodex

                Image {
                    id: codexBase
                    anchors.fill: parent
                    source: Qt.resolvedUrl("../assets/codex.svg")
                    sourceSize: Qt.size(48, 48)
                    fillMode: Image.PreserveAspectFit
                    smooth: true; mipmap: true
                    // thinner-stroked than the Claude glyph → needs more presence
                    // than the glyph's 0.25 faint base to stay recognizable
                    opacity: 0.5
                    layer.enabled: true
                    layer.smooth: true
                    layer.effect: ShaderEffect {
                        property color tintColor: root.ink
                        fragmentShader: Qt.resolvedUrl("../shaders/logo-tint.frag.qsb")
                    }
                }
                Item {
                    clip: true
                    width: parent.width
                    anchors.bottom: parent.bottom
                    height: rootMod.pct5hStep > 0
                        ? Math.min(parent.height, Math.max(parent.height * rootMod.pct5hStep / 100, parent.height * 0.22))
                        : 0
                    Behavior on height { NumberAnimation { duration: 600; easing.type: Easing.OutCubic } }
                    Image {
                        width: iconItem.width; height: iconItem.height
                        anchors.bottom: parent.bottom
                        source: Qt.resolvedUrl("../assets/codex.svg")
                        sourceSize: Qt.size(48, 48)
                        fillMode: Image.PreserveAspectFit
                        smooth: true; mipmap: true
                        layer.enabled: true
                        layer.smooth: true
                        layer.effect: ShaderEffect {
                            property color tintColor: root.seal
                            fragmentShader: Qt.resolvedUrl("../shaders/logo-tint.frag.qsb")
                        }
                    }
                }
            }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: rootMod.blocked
                ? "BLK"
                : (rootMod.selSignal ? String(rootMod.pct5h).padStart(2, "0") + "%" : "··")
            color: rootMod.blocked
                ? root.seal
                : Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.85)
            font.family: root.mono
            font.pixelSize: 12
            Behavior on color { ColorAnimation { duration: 200 } }
        }
    }

    // ── Claude data polling ──
    Process {
        id: readClaude
        command: ["bash", "-c",
            "f=\"$HOME/.cache/claude-usage.json\"; stat -c %Y \"$f\" 2>/dev/null; cat \"$f\" 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                var raw = this.text
                var nl  = raw.indexOf("\n")
                var mtime = nl > 0 ? (parseInt(raw.substring(0, nl)) || 0) : 0
                var jsonStr = nl > 0 ? raw.substring(nl + 1) : ""
                var ageOk = mtime > 0 && (Date.now() / 1000 - mtime) < 900
                try {
                    var d = JSON.parse(jsonStr.trim())
                    rootMod.clHas   = true
                    rootMod.clFresh = ageOk && d._source !== "stale"
                    rootMod.clPct5h = Math.round((parseFloat(d["5h-utilization"]) || 0) * 100)
                    rootMod.clPct7d = Math.round((parseFloat(d["7d-utilization"]) || 0) * 100)
                    rootMod.clBlocked = d.status === "rejected" || d.status === "blocked"
                    rootMod.clReset5hTs = parseInt(d["5h-reset"]) || 0

                    var tokUsed  = ((d["_tokens_used"]  || 0) / 1e6).toFixed(2) + "M"
                    var tokLimit = ((d["_window_limit"] || 0) / 1e6).toFixed(1) + "M"
                    var rateH    = Math.round((d["_rate_per_hour"] || 0) / 1000)
                    rootMod.clTokens = (d["_tokens_used"] ? tokUsed + " / " + tokLimit + " tokens" : "")
                    rootMod.clRate   = rateH > 0 ? rateH + "k tok/h" : ""
                } catch (e) {
                    rootMod.clHas = false; rootMod.clFresh = false
                    rootMod.clPct5h = 0; rootMod.clPct7d = 0
                    rootMod.clTokens = ""; rootMod.clRate = ""
                }
            }
        }
    }

    // ── Codex data polling ──
    Process {
        id: readCodex
        command: ["bash", "-c",
            "f=\"$HOME/.cache/codex-usage.json\"; stat -c %Y \"$f\" 2>/dev/null; cat \"$f\" 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                var raw = this.text
                var nl  = raw.indexOf("\n")
                var mtime = nl > 0 ? (parseInt(raw.substring(0, nl)) || 0) : 0
                var jsonStr = nl > 0 ? raw.substring(nl + 1) : ""
                var ageOk = mtime > 0 && (Date.now() / 1000 - mtime) < 900
                try {
                    var d = JSON.parse(jsonStr.trim())
                    rootMod.cxHas   = true
                    rootMod.cxFresh = ageOk && d._source !== "stale"
                    rootMod.cxPct5h = Math.round((parseFloat(d["5h-utilization"]) || 0) * 100)
                    rootMod.cxPct7d = Math.round((parseFloat(d["7d-utilization"]) || 0) * 100)
                    rootMod.cxReset5hTs = parseInt(d["5h-reset"]) || 0
                    rootMod.cxReset7dTs = parseInt(d["7d-reset"]) || 0
                    rootMod.cxPlan = d._plan || ""
                    var cxUsed = (d["_tokens_used"] || 0), cxLim = (d["_window_limit"] || 0)
                    rootMod.cxTokens = cxUsed ? (cxUsed / 1e6).toFixed(2) + "M / " + (cxLim / 1e6).toFixed(1) + "M tokens" : ""
                    var cxRateH = Math.round((d["_rate_per_hour"] || 0) / 1000)
                    rootMod.cxRate = cxRateH > 0 ? cxRateH + "k tok/h" : ""
                    rootMod.cxTodayTok = parseInt(d._today_tokens) || 0
                } catch (e) {
                    rootMod.cxHas = false; rootMod.cxFresh = false
                    rootMod.cxPct5h = 0; rootMod.cxPct7d = 0
                    rootMod.cxPlan = ""; rootMod.cxTokens = ""; rootMod.cxRate = ""; rootMod.cxTodayTok = 0
                }
            }
        }
    }

    Timer {
        interval: 30000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: {
            readClaude.running = false; readClaude.running = true
            readCodex.running = false;  readCodex.running = true
        }
    }

    TooltipMixin { id: tip; root: rootMod.root; owner: rootMod; text: rootMod.tooltipText }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true; cursorShape: Qt.PointingHandCursor
        onEntered: if (shown) tip.show()
        onExited: { tip.hide() }
        onClicked: { tip.hide(); root.aiUsageVisible = !root.aiUsageVisible }
    }
}
