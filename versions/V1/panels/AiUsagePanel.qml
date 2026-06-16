import QtQuick
import "../modules"
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// AI usage panel: shows BOTH Claude Code + OpenAI Codex usage and lets the user
// switch which tool's icon the bar pill displays (root.aiTool). Opened from the
// combined AI pill (ClaudeWidget). Reads the same caches the bar widget reads.
PanelWindow {
    id: aiPanel
    required property var root

    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "omarchy-ai-usage"

    readonly property int barBottom: 35
    readonly property int gap: 8

    // ── Claude state ──
    property int    clPct5h: 0
    property int    clPct7d: 0
    property int    clReset5hTs: 0
    property string clTokens: ""
    property string clRate: ""
    property bool   clFresh: false
    property bool   clHas: false

    // ── Codex state ──
    property int    cxPct5h: 0
    property int    cxPct7d: 0
    property int    cxReset5hTs: 0
    property int    cxReset7dTs: 0
    property string cxPlan: ""
    property string cxTokens: ""
    property string cxRate: ""
    property int    cxToday: 0
    property bool   cxFresh: false
    property bool   cxHas: false

    function fmtReset(ts) {
        var now = Date.now() / 1000
        if (!(ts > now)) return "—"
        var mins = Math.round((ts - now) / 60)
        if (mins < 60) return mins + "m"
        var h = Math.floor(mins / 60), m = mins % 60
        if (h < 24) return h + "h " + m + "m"
        var d = Math.floor(h / 24); return d + "d " + (h % 24) + "h"
    }

    property real reveal: root.aiUsageVisible ? 1 : 0
    Behavior on reveal {
        NumberAnimation {
            duration: root.aiUsageVisible ? 160 : 120
            easing.type: root.aiUsageVisible ? Easing.OutCubic : Easing.InCubic
        }
    }
    visible: reveal > 0.001
    WlrLayershell.keyboardFocus: root.aiUsageVisible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    MouseArea {
        anchors.fill: parent
        onClicked: root.aiUsageVisible = false
    }

    // ── reusable label · bar · % row ──
    component UsageRow: Item {
        property string label: ""
        property int pct: 0
        property bool dim: false
        width: parent ? parent.width : 0
        height: 16
        Text {
            id: rowLbl
            anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
            text: label; color: aiPanel.root.sumi
            font.family: aiPanel.root.mono; font.pixelSize: 11; font.letterSpacing: 1
        }
        Text {
            id: rowVal
            anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
            text: pct + "%"
            color: dim ? aiPanel.root.sumi : aiPanel.root.seal
            font.family: aiPanel.root.mono; font.pixelSize: 11; font.weight: Font.Medium
        }
        Rectangle {
            anchors.left: rowLbl.right; anchors.leftMargin: 8
            anchors.right: rowVal.left; anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            height: 8; radius: 4
            color: Qt.rgba(aiPanel.root.seal.r, aiPanel.root.seal.g, aiPanel.root.seal.b, 0.15)
            Rectangle {
                width: parent.width * Math.min(100, parent ? pct : 0) / 100
                height: parent.height; radius: 4
                color: pct >= 90 ? aiPanel.root.sealRaw : aiPanel.root.seal
                Behavior on width { NumberAnimation { duration: 300 } }
            }
        }
    }

    // ── reusable key/value detail row ──
    component DetailRow: Row {
        property string k: ""
        property string v: ""
        width: parent ? parent.width : 0
        Text {
            text: k; color: aiPanel.root.sumi
            font.family: aiPanel.root.mono; font.pixelSize: 11
            width: parent.width * 0.45
        }
        Text {
            text: v; color: aiPanel.root.ink
            font.family: aiPanel.root.mono; font.pixelSize: 11
            width: parent.width * 0.55; horizontalAlignment: Text.AlignRight
        }
    }

    Rectangle {
        id: card
        width: 320
        height: col.implicitHeight + 24
        radius: reveal > 0.001 ? root.pillRadius : 0
        color: root.bg
        border.color: root.pillBorder
        border.width: root.pillBorderW
        PillShadow { theme: root }

        x: Math.round(Math.max(6, Math.min(root.aiBarX - width / 2, parent.width - width - 6)))
        y: root.barPosition === "bottom" ? (parent.height - barBottom - gap - height) : (barBottom + gap)
        opacity: aiPanel.reveal
        focus: root.aiUsageVisible

        Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Escape) {
                root.aiUsageVisible = false;
                event.accepted = true;
            }
        }

        MouseArea { anchors.fill: parent; onClicked: {} }

        Column {
            id: col
            anchors.fill: parent
            anchors.margins: 12
            spacing: 8

            // ── header ──
            Item {
                width: parent.width
                height: 24
                Text {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: "AI USAGE"
                    color: root.ink
                    font.family: root.mono
                    font.pixelSize: 13
                    font.letterSpacing: 2
                    font.weight: Font.Medium
                }
                Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: "✕"
                    color: closeMa.containsMouse ? root.seal : root.sumi
                    font.pixelSize: 12
                    Behavior on color { ColorAnimation { duration: 120 } }
                    MouseArea {
                        id: closeMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.aiUsageVisible = false
                    }
                }
            }

            // ── segmented switch: which tool the bar shows ──
            Row {
                width: parent.width
                height: 28
                spacing: 6
                Repeater {
                    model: [ { id: "claude", label: "Claude" }, { id: "codex", label: "Codex" } ]
                    Rectangle {
                        required property var modelData
                        width: (parent.width - 6) / 2
                        height: 28; radius: root.tileRadius
                        readonly property bool active: root.aiTool === modelData.id
                        color: active ? root.seal
                              : segMa.containsMouse ? Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.18)
                              : Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.08)
                        Behavior on color { ColorAnimation { duration: 120 } }
                        Text {
                            anchors.centerIn: parent
                            text: modelData.label
                            color: parent.active ? root.paper : root.ink
                            font.family: root.mono; font.pixelSize: 11
                            font.weight: parent.active ? Font.Medium : Font.Normal
                        }
                        MouseArea {
                            id: segMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.aiTool = parent.modelData.id
                        }
                    }
                }
            }

            Rectangle { width: parent.width; height: 1; color: root.sep }

            // ── Claude Code ──
            Item {
                width: parent.width; height: 16
                Text {
                    anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                    text: "Claude Code"; color: root.ink
                    font.family: root.mono; font.pixelSize: 12; font.weight: Font.Medium
                }
                Text {
                    anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                    text: aiPanel.clFresh ? "live" : "stale"
                    color: aiPanel.clFresh ? root.sumi : root.sealRaw
                    font.family: root.mono; font.pixelSize: 10
                }
            }
            Text {
                visible: !aiPanel.clHas
                width: parent.width
                text: "no data — run claude"
                color: root.sumi; font.family: root.mono; font.pixelSize: 11
            }
            UsageRow { visible: aiPanel.clHas; label: "5h"; pct: aiPanel.clPct5h; dim: !aiPanel.clFresh }
            UsageRow { visible: aiPanel.clHas; label: "7d"; pct: aiPanel.clPct7d; dim: !aiPanel.clFresh }
            DetailRow { visible: aiPanel.clHas; k: "Resets in"; v: aiPanel.fmtReset(aiPanel.clReset5hTs) }
            DetailRow { visible: aiPanel.clHas && aiPanel.clTokens !== ""; k: "Tokens"; v: aiPanel.clTokens }
            DetailRow { visible: aiPanel.clHas && aiPanel.clRate !== "";   k: "Rate"; v: aiPanel.clRate }

            Rectangle { width: parent.width; height: 1; color: root.sep }

            // ── OpenAI Codex ──
            Item {
                width: parent.width; height: 16
                Text {
                    anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                    text: "OpenAI Codex" + (aiPanel.cxPlan ? "  · " + aiPanel.cxPlan : "")
                    color: root.ink
                    font.family: root.mono; font.pixelSize: 12; font.weight: Font.Medium
                }
                Text {
                    anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                    text: aiPanel.cxFresh ? "live" : "stale"
                    color: aiPanel.cxFresh ? root.sumi : root.sealRaw
                    font.family: root.mono; font.pixelSize: 10
                }
            }
            Text {
                visible: !aiPanel.cxHas
                width: parent.width
                text: "no data — run codex"
                color: root.sumi; font.family: root.mono; font.pixelSize: 11
            }
            UsageRow { visible: aiPanel.cxHas; label: "5h"; pct: aiPanel.cxPct5h; dim: !aiPanel.cxFresh }
            UsageRow { visible: aiPanel.cxHas; label: "7d"; pct: aiPanel.cxPct7d; dim: !aiPanel.cxFresh }
            DetailRow { visible: aiPanel.cxHas; k: "5h resets in"; v: aiPanel.fmtReset(aiPanel.cxReset5hTs) }
            DetailRow { visible: aiPanel.cxHas; k: "7d resets in"; v: aiPanel.fmtReset(aiPanel.cxReset7dTs) }
            DetailRow { visible: aiPanel.cxHas && aiPanel.cxTokens !== ""; k: "Tokens"; v: aiPanel.cxTokens }
            DetailRow { visible: aiPanel.cxHas && aiPanel.cxRate !== "";   k: "Rate"; v: aiPanel.cxRate }
            DetailRow { visible: aiPanel.cxHas && aiPanel.cxToday > 0; k: "Today"; v: (aiPanel.cxToday / 1e6).toFixed(2) + "M tok" }
        }
    }

    // ── data: read both caches while the panel is open ──
    Process {
        id: readClaude
        command: ["bash", "-c",
            "f=\"$HOME/.cache/claude-usage.json\"; stat -c %Y \"$f\" 2>/dev/null; cat \"$f\" 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                var raw = this.text, nl = raw.indexOf("\n")
                var mtime = nl > 0 ? (parseInt(raw.substring(0, nl)) || 0) : 0
                var ageOk = mtime > 0 && (Date.now() / 1000 - mtime) < 900
                try {
                    var d = JSON.parse((nl > 0 ? raw.substring(nl + 1) : "").trim())
                    aiPanel.clHas = true
                    aiPanel.clFresh = ageOk && d._source !== "stale"
                    aiPanel.clPct5h = Math.round((parseFloat(d["5h-utilization"]) || 0) * 100)
                    aiPanel.clPct7d = Math.round((parseFloat(d["7d-utilization"]) || 0) * 100)
                    aiPanel.clReset5hTs = parseInt(d["5h-reset"]) || 0
                    var used = (d["_tokens_used"] || 0), lim = (d["_window_limit"] || 0)
                    aiPanel.clTokens = used ? (used / 1e6).toFixed(2) + "M / " + (lim / 1e6).toFixed(1) + "M" : ""
                    var rateH = Math.round((d["_rate_per_hour"] || 0) / 1000)
                    aiPanel.clRate = rateH > 0 ? rateH + "k tok/h" : ""
                } catch (e) {
                    aiPanel.clHas = false; aiPanel.clFresh = false
                    aiPanel.clPct5h = 0; aiPanel.clPct7d = 0
                    aiPanel.clTokens = ""; aiPanel.clRate = ""
                }
            }
        }
    }
    Process {
        id: readCodex
        command: ["bash", "-c",
            "f=\"$HOME/.cache/codex-usage.json\"; stat -c %Y \"$f\" 2>/dev/null; cat \"$f\" 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                var raw = this.text, nl = raw.indexOf("\n")
                var mtime = nl > 0 ? (parseInt(raw.substring(0, nl)) || 0) : 0
                var ageOk = mtime > 0 && (Date.now() / 1000 - mtime) < 900
                try {
                    var d = JSON.parse((nl > 0 ? raw.substring(nl + 1) : "").trim())
                    aiPanel.cxHas = true
                    aiPanel.cxFresh = ageOk && d._source !== "stale"
                    aiPanel.cxPct5h = Math.round((parseFloat(d["5h-utilization"]) || 0) * 100)
                    aiPanel.cxPct7d = Math.round((parseFloat(d["7d-utilization"]) || 0) * 100)
                    aiPanel.cxReset5hTs = parseInt(d["5h-reset"]) || 0
                    aiPanel.cxReset7dTs = parseInt(d["7d-reset"]) || 0
                    aiPanel.cxPlan = d._plan || ""
                    var cxUsed = (d["_tokens_used"] || 0), cxLim = (d["_window_limit"] || 0)
                    aiPanel.cxTokens = cxUsed ? (cxUsed / 1e6).toFixed(2) + "M / " + (cxLim / 1e6).toFixed(1) + "M" : ""
                    var cxRateH = Math.round((d["_rate_per_hour"] || 0) / 1000)
                    aiPanel.cxRate = cxRateH > 0 ? cxRateH + "k tok/h" : ""
                    aiPanel.cxToday = parseInt(d._today_tokens) || 0
                } catch (e) {
                    aiPanel.cxHas = false; aiPanel.cxFresh = false
                    aiPanel.cxPct5h = 0; aiPanel.cxPct7d = 0
                    aiPanel.cxPlan = ""; aiPanel.cxTokens = ""; aiPanel.cxRate = ""; aiPanel.cxToday = 0
                }
            }
        }
    }

    // refresh the moment the panel opens, then gently while it stays open
    Timer {
        interval: 5000
        running: aiPanel.visible && root.aiUsageVisible
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            readClaude.running = false; readClaude.running = true
            readCodex.running = false;  readCodex.running = true
        }
    }
}
