import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io

// Combined AI-usage pill (Claude Code + OpenAI Codex + OpenCode). The bar shows ONE tool
// (root.aiTool) as a themed-tinted SVG with a bottom-up usage fill; the tooltip
// shows all tracked tools; clicking opens the AiUsagePanel where the tool can be switched.
// Gating is unchanged: root.modClaude is the on/off toggle for the whole pill.
Item {
    id: rootMod
    objectName: "ai-wrapper"
    required property var root

    // ── which tool the bar pill displays ──
    readonly property string effectiveTool: (root.aiTool === "claude" && !clHas && !clActive && cxHas)
        ? "codex" : root.aiTool
    readonly property bool isCodex: effectiveTool === "codex"
    readonly property bool isOpenCode: effectiveTool === "opencode"
    readonly property bool isLogo: isCodex || isOpenCode
    readonly property url  logoSource: Qt.resolvedUrl(isOpenCode ? "../assets/opencode-mark.svg" : "../assets/codex.svg")
    readonly property var  logoSourceSize: isOpenCode ? Qt.size(22, 14) : Qt.size(48, 48)
    readonly property int  ocMarkW: 22
    readonly property int  ocMarkH: 14

    // ── Claude: process detection is local (drives the pill's visibility); all
    //    usage data comes from root.ai* — the single shared parse in Theme.qml that
    //    AiUsagePanel renders from too, so the two views can't drift apart. ──
    property bool clActive: false
    readonly property bool   clFresh:     root.aiClFresh
    readonly property int    clPct5h:     root.aiClPct5h
    readonly property int    clPct7d:     root.aiClPct7d
    readonly property bool   clBlocked:   root.aiClBlocked
    readonly property string clTokens:    root.aiClTokens
    readonly property string clRate:      root.aiClRate
    readonly property int    clReset5hTs: root.aiClReset5hTs
    readonly property int    clReset7dTs: root.aiClReset7dTs
    readonly property int    clToday:     root.aiClToday
    readonly property bool   clHas:       root.aiClHas

    // ── Codex ──
    property bool cxActive: false
    readonly property bool   cxFresh:     root.aiCxFresh
    readonly property string cxState:     root.aiCxState
    readonly property bool   cxHas5h:     root.aiCxHas5h
    readonly property bool   cxHasWeekly: root.aiCxHasWeekly
    readonly property int    cxPct5h:     root.aiCxPct5h
    readonly property int    cxPct7d:     root.aiCxPct7d    // weekly
    readonly property string cxPlan:      root.aiCxPlan
    readonly property string cxTokens:    root.aiCxTokens
    readonly property string cxRate:      root.aiCxRate
    readonly property int    cxReset5hTs: root.aiCxReset5hTs
    readonly property int    cxReset7dTs: root.aiCxReset7dTs
    readonly property bool   cxHas:       root.aiCxHas
    readonly property bool   cxCreditsAvailable: root.aiCxCreditsAvailable
    readonly property string cxCredits: root.aiCxCredits

    // ── OpenCode ──
    property bool ocActive: false
    readonly property bool   ocFresh:     root.aiOcFresh
    readonly property int    ocPct5h:     root.aiOcPct5h
    readonly property int    ocPct7d:     root.aiOcPct7d
    readonly property string ocPlan:      root.aiOcPlan
    readonly property string ocTokens:    root.aiOcTokens
    readonly property string ocRate:      root.aiOcRate
    readonly property string ocModel:     root.aiOcModel
    readonly property int    ocToday:     root.aiOcToday
    readonly property bool   ocHas:       root.aiOcHas
    readonly property bool debugLayout: Quickshell.env("QS_BAR_LAYOUT_DEBUG") === "1"

    // ── per-tool signal (active OR fresh non-zero usage) ──
    readonly property bool clSignal: clActive || (clPct5h > 0 && clFresh)
    readonly property bool cxSignal: cxActive || ((cxHas5h ? cxPct5h : cxPct7d) > 0 && cxFresh)
    readonly property bool ocSignal: ocActive || ((ocPct5h > 0 || ocToday > 0) && ocFresh)

    // ── selected-tool display values ──
    readonly property int  pct5h:   isOpenCode ? ocPct5h : (isCodex ? (cxHas5h ? cxPct5h : cxPct7d) : clPct5h)
    readonly property int  pct5hStep: Math.round(pct5h / 5) * 5
    readonly property int  pct5hRemaining: Math.max(0, 100 - pct5h)
    readonly property bool selFresh: isOpenCode ? ocFresh : (isCodex ? cxFresh : clFresh)
    readonly property bool selSignal: isOpenCode ? ocSignal : (isCodex ? cxSignal : clSignal)
    readonly property bool barHasData: isCodex ? (cxHas || cxActive) : selSignal
    readonly property bool blocked:  (isCodex || isOpenCode) ? false : clBlocked

    // The widget toggle controls visibility. Signal still drives the usage fill/tooltip,
    // but an idle AI tool should not make the ControlPanel toggle look broken.
    readonly property bool shown: root.aiWidgetVisible

    onCxActiveChanged: root.codexActive = cxActive
    Component.onCompleted: root.codexActive = cxActive
    Component.onDestruction: if (root) root.codexActive = false

    readonly property string tooltipText: {
        var lines = []
        if (isCodex) {
                lines.push("OpenAI Codex" + (cxPlan ? "  (" + cxPlan + ")" : ""))
                if (cxHas || cxActive) {
                    var cx5 = root.aiFmtReset(cxReset5hTs)
                    var cx7 = root.aiFmtReset(cxReset7dTs)
                    lines.push("state: " + cxState)
                    if (cxHasWeekly) lines.push("weekly remaining: " + (100 - cxPct7d) + "%" + (cx7 ? "  resets in " + cx7 : ""))
                    if (cxHas5h) lines.push("5h remaining: " + (100 - cxPct5h) + "%" + (cx5 ? "  resets in " + cx5 : ""))
                    if (cxCreditsAvailable) lines.push("credits remaining: " + cxCredits)
                    if (cxTokens) lines.push(cxTokens + " tokens" + (cxRate ? "  · " + cxRate : ""))
            } else {
                lines.push("no data yet - run codex or install the AI backend")
            }
            return lines.join("\n")
        }
        if (clHas || clActive) {
            lines.push("Claude Code")
            var cr = root.aiFmtReset(clReset5hTs)
            lines.push("5h: " + clPct5h + "%" + (cr ? "  (reset in " + cr + ")" : ""))
            var c7 = root.aiFmtReset(clReset7dTs)
            if (clPct7d > 0) lines.push("7d: " + clPct7d + "%" + (c7 ? "  (reset in " + c7 + ")" : ""))
            if (clTokens)    lines.push(clTokens + " tokens" + (clRate ? "  · " + clRate : ""))
            if (clToday > 0) lines.push("today: " + (clToday / 1e6).toFixed(2) + "M tok")
        }
        if (cxHas || cxActive) {
            if (lines.length) lines.push("")
            lines.push("OpenAI Codex" + (cxPlan ? "  (" + cxPlan + ")" : ""))
            var x5 = root.aiFmtReset(cxReset5hTs)
            if (cxHas5h) lines.push("5h remaining: " + (100 - cxPct5h) + "%" + (x5 ? "  (reset in " + x5 + ")" : ""))
            var x7 = root.aiFmtReset(cxReset7dTs)
            if (cxHasWeekly) lines.push("weekly remaining: " + (100 - cxPct7d) + "%" + (x7 ? "  (reset in " + x7 + ")" : ""))
            if (cxCreditsAvailable) lines.push("credits remaining: " + cxCredits)
            if (cxTokens) lines.push(cxTokens + " tokens" + (cxRate ? "  · " + cxRate : ""))
        }
        if (ocHas || ocActive) {
            if (lines.length) lines.push("")
            lines.push("OpenCode" + (ocPlan ? "  (" + ocPlan + ")" : ""))
            lines.push("5h: " + ocPct5h + "%  ·  7d: " + ocPct7d + "%")
            if (ocTokens) lines.push(ocTokens + " tokens" + (ocRate ? "  · " + ocRate : ""))
            if (ocToday > 0) lines.push("today: " + (ocToday / 1e6).toFixed(2) + "M tok")
            if (ocModel) lines.push(ocModel)
        }
        return lines.length ? lines.join("\n") : "AI usage"
    }

    // keep rendered until the collapse animation finishes
    visible: implicitWidth > 0.5
    implicitWidth: shown ? row.implicitWidth + 18 : 0
    implicitHeight: 28
    width: implicitWidth
    height: implicitHeight
    opacity: shown ? 1 : 0

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
    Process {
        id: detectOpenCode
        command: ["bash", "-c", "ps -eo args | grep -E '(^|/| )opencode( |$)|opencode-ai' | grep -vE 'grep|opencode-usage' >/dev/null && echo 1 || echo 0"]
        stdout: StdioCollector { onStreamFinished: { rootMod.ocActive = (this.text.trim() === "1") } }
    }
    Timer {
        interval: 5000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: {
            detectClaude.running = false; detectClaude.running = true
            detectCodex.running = false;  detectCodex.running = true
            detectOpenCode.running = false; detectOpenCode.running = true
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
        // Codex/OpenCode use vector marks themed via the shared logo tint shader.
        Item {
            id: iconItem
            anchors.verticalCenter: parent.verticalCenter
            implicitWidth: rootMod.isOpenCode ? rootMod.ocMarkW : 15
            implicitHeight: rootMod.isOpenCode ? rootMod.ocMarkH : 15
            width: implicitWidth
            height: implicitHeight

            // ── Claude: nerd-font glyph (original look) ──
            Item {
                anchors.centerIn: parent
                visible: !rootMod.isLogo
                implicitWidth: glyphBase.implicitWidth
                implicitHeight: glyphBase.implicitHeight

                UiText {
                    id: glyphBase
                    text: String.fromCodePoint(0xF167A)
                    renderType: Text.QtRendering
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
                    UiText {
                        anchors.bottom: parent.bottom
                        text: String.fromCodePoint(0xF167A)
                        renderType: Text.QtRendering
                        color: root.seal
                        font.family: root.mono
                        font.pixelSize: 14
                        Behavior on color { ColorAnimation { duration: 200 } }
                    }
                }
            }

            // ── Logo tools: tinted SVG ──
            Item {
                anchors.fill: parent
                visible: rootMod.isLogo

                Image {
                    id: codexBase
                    anchors.fill: parent
                    source: rootMod.logoSource
                    sourceSize: rootMod.logoSourceSize
                    fillMode: Image.PreserveAspectFit
                    smooth: !rootMod.isOpenCode
                    mipmap: !rootMod.isOpenCode
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
                        source: rootMod.logoSource
                        sourceSize: rootMod.logoSourceSize
                        fillMode: Image.PreserveAspectFit
                        smooth: !rootMod.isOpenCode
                        mipmap: !rootMod.isOpenCode
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

        UiText {
            anchors.verticalCenter: parent.verticalCenter
            text: rootMod.blocked
                ? "BLK"
                : rootMod.isCodex
                    ? (rootMod.barHasData ? String(rootMod.pct5hRemaining).padStart(2, "0") + "%" : "··")
                    : (rootMod.barHasData ? String(rootMod.pct5h).padStart(2, "0") + "%" : "··")
            color: rootMod.blocked
                ? root.seal
                : Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.85)
            font.family: root.mono
            font.pixelSize: 12
            Behavior on color { ColorAnimation { duration: 200 } }
        }
    }

    TooltipMixin { id: tip; root: rootMod.root; owner: rootMod; text: rootMod.tooltipText }

    Rectangle {
        visible: rootMod.debugLayout
        anchors.fill: parent
        radius: root.pillRadius
        color: Qt.rgba(0.16, 0.78, 0.43, 0.10)
        border.color: Qt.rgba(0.16, 0.78, 0.43, 0.75)
        border.width: 1
        z: 50
    }

    Rectangle {
        visible: rootMod.debugLayout
        anchors.fill: row
        radius: root.pillRadius
        color: Qt.rgba(0.22, 0.62, 0.90, 0.08)
        border.color: Qt.rgba(0.22, 0.62, 0.90, 0.82)
        border.width: 1
        z: 51
    }

    BarWidgetButton {
        anchors.fill: parent
        theme: root
        traceName: "ai-handler"
        hoverEnabled: true; cursorShape: Qt.PointingHandCursor
        onEntered: {
            if (shown) {
                root.refreshAiUsage()
                tip.show()
            }
            if (rootMod.debugLayout) console.log("ClaudeWidget hover entered outer=" + rootMod.width + "x" + rootMod.height)
        }
        onExited: {
            tip.hide()
            if (rootMod.debugLayout) console.log("ClaudeWidget hover exited outer=" + rootMod.width + "x" + rootMod.height)
        }
        onPressed: function(mouse) {
            if (!rootMod.debugLayout) return
            var scene = mapToItem(null, mouse.x, mouse.y)
            console.log("ClaudeWidget press local=" + mouse.x + "," + mouse.y
                + " scene=" + scene.x + "," + scene.y
                + " outer=" + rootMod.x + "," + rootMod.y + " " + rootMod.width + "x" + rootMod.height
                + " visible=" + row.implicitWidth + "x" + row.implicitHeight)
        }
        onClicked: function(mouse) {
            if (rootMod.debugLayout) console.log("ClaudeWidget click local=" + mouse.x + "," + mouse.y)
            tip.hide()
            root.aiTool = "codex"
            root.refreshAiUsage(true)
            root.aiUsageVisible = !root.aiUsageVisible
        }
    }
}
