import QtQuick
import "../modules"
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

PanelWindow {
    id: cpuPanel
    required property var root

    screen: root.activePopupScreen

    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "omarchy-cpu"

    readonly property int barBottom: 35
    readonly property int gap: 8
    readonly property int maxSamples: 30
    readonly property string cpuIcon: "\uf2db"
    readonly property string ramIcon: "\uf538"

    property int cpuPct: 0
    property int cpuTemp: 0
    property var cpuHistory: []
    property string gpuDriver: ""
    property int gpuUtil: 0
    property int gpuTemp: 0
    property int gpuMemUsed: 0
    property int gpuMemTotal: 0
    property var gpuHistory: []
    readonly property bool hasGpu: gpuDriver !== "" && gpuDriver !== "none"
    property int ramPct: 0
    property real ramUsedGiB: 0.0
    property real ramTotalGiB: 0.0

    function tempText(v) {
        return v > 0 ? v + "\u00B0C" : "--\u00B0C"
    }

    function pushSample(history, value) {
        var h = history.slice()
        h.push(Math.max(0, Math.min(1, value / 100)))
        if (h.length > maxSamples) h.shift()
        return h
    }

    function mibToGib(v) {
        return (Math.max(0, v) / 1024).toFixed(1)
    }

    function vramPct() {
        return gpuMemTotal > 0 ? Math.max(0, Math.min(100, Math.round(gpuMemUsed * 100 / gpuMemTotal))) : 0
    }

    property real reveal: root.cpuVisible ? 1 : 0
    Behavior on reveal {
        NumberAnimation {
            duration: 180
            easing.type: root.cpuVisible ? Easing.OutCubic : Easing.InCubic
        }
    }
    visible: reveal > 0.001
    WlrLayershell.keyboardFocus: root.cpuVisible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    MouseArea {
        anchors.fill: parent
        onClicked: root.cpuVisible = false
    }

    Rectangle {
        id: card
        width: 640
        height: col.implicitHeight + 24
        radius: reveal > 0.001 ? root.pillRadius : 0
        color: root.bg
        border.color: root.pillBorder
        border.width: root.pillBorderW
        PillShadow { theme: root }

        x: Math.round(Math.max(6, Math.min(root.cpuBarX - width / 2, parent.width - width - 6)))
        y: root.barPosition === "bottom" ? (parent.height - barBottom - gap - height) : (barBottom + gap)
        opacity: cpuPanel.reveal
        scale: 0.96 + 0.04 * cpuPanel.reveal
        transformOrigin: root.barPosition === "bottom" ? Item.Bottom : Item.Top
        focus: root.cpuVisible

        Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Escape) {
                root.cpuVisible = false;
                event.accepted = true;
            }
        }

        MouseArea { anchors.fill: parent; onClicked: {} }

        Column {
            id: col
            anchors.fill: parent
            anchors.margins: 12
            spacing: 6

            Item {
                width: parent.width
                height: 18
                UiText {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: "SYSTEM"
                    color: root.ink
                    font.family: root.mono
                    font.pixelSize: 12
                    font.letterSpacing: 2
                    font.weight: Font.Medium
                }
                UiText {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: "\u2715"
                    color: closeMa.containsMouse ? root.seal : root.sumi
                    font.pixelSize: 12
                    Behavior on color { ColorAnimation { duration: 120 } }
                    MouseArea {
                        id: closeMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.cpuVisible = false
                    }
                }
            }

            Rectangle { width: parent.width; height: 1; color: root.sep }

            Grid {
                width: parent.width
                columns: 3
                rowSpacing: 0
                columnSpacing: 10

                MonitorCard {
                    root: cpuPanel.root
                    width: (parent.width - 20) / 3
                    height: 162
                    icon: cpuPanel.cpuIcon
                    title: "CPU"
                    primary: cpuPanel.tempText(cpuPanel.cpuTemp)
                    secondary: cpuPanel.cpuPct + "%"
                    history: cpuPanel.cpuHistory
                    bottomLabel: "USAGE"
                    bottomText: cpuPanel.cpuPct + "%"
                    bottomPercent: cpuPanel.cpuPct
                }

                MonitorCard {
                    root: cpuPanel.root
                    width: (parent.width - 20) / 3
                    height: 162
                    gpuIcon: true
                    title: "GPU"
                    primary: cpuPanel.hasGpu ? cpuPanel.tempText(cpuPanel.gpuTemp) : "--\u00B0C"
                    secondary: cpuPanel.hasGpu ? cpuPanel.gpuUtil + "%" : "offline"
                    history: cpuPanel.gpuHistory
                    bottomLabel: "VRAM"
                    bottomText: cpuPanel.gpuMemTotal > 0
                                ? cpuPanel.mibToGib(cpuPanel.gpuMemUsed) + " / " + cpuPanel.mibToGib(cpuPanel.gpuMemTotal) + " GiB"
                                : "0.0 / 0.0 GiB"
                    bottomPercent: cpuPanel.vramPct()
                }

                MonitorCard {
                    root: cpuPanel.root
                    width: (parent.width - 20) / 3
                    height: 162
                    icon: cpuPanel.ramIcon
                    title: "RAM"
                    primary: cpuPanel.ramUsedGiB.toFixed(1) + " GiB"
                    secondary: cpuPanel.ramPct + "%"
                    bottomLabel: "MEMORY"
                    bottomText: cpuPanel.ramUsedGiB.toFixed(1) + " / " + cpuPanel.ramTotalGiB.toFixed(1) + " GiB"
                    bottomPercent: cpuPanel.ramPct
                    showSparkline: false
                }
            }

            Rectangle {
                width: parent.width
                height: 36
                radius: root.tileRadius
                color: btopMa.containsMouse ? root.fillPrimaryHover : root.seal
                Behavior on color { ColorAnimation { duration: 120 } }
                UiText {
                    anchors.centerIn: parent
                    text: "Open btop"
                    color: root.paper
                    font.family: root.mono
                    font.pixelSize: 12
                    font.weight: Font.Medium
                }
                MouseArea {
                    id: btopMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.cpuVisible = false;
                        btopRunner.running = false;
                        btopRunner.running = true;
                    }
                }
            }
        }
    }

    component MonitorCard: Rectangle {
        required property var root
        property string icon: ""
        property string title: ""
        property string primary: ""
        property string secondary: ""
        property string bottomLabel: ""
        property string bottomText: ""
        property real bottomPercent: 0
        property var history: []
        property bool gpuIcon: false
        property bool showSparkline: true
        property bool showProgress: true

        radius: root.tileRadius
        color: root.frameWeak
        border.color: root.sep
        border.width: 1

        Column {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 5

            Row {
                width: parent.width
                height: 18
                spacing: 6

                UiText {
                    visible: !gpuIcon
                    width: 18
                    anchors.verticalCenter: parent.verticalCenter
                    text: icon
                    color: root.seal
                    font.family: root.mono
                    font.pixelSize: 16
                    horizontalAlignment: Text.AlignHCenter
                }
                GpuBoardIcon {
                    visible: gpuIcon
                    anchors.verticalCenter: parent.verticalCenter
                    tint: root.seal
                }
                UiText {
                    width: parent.width - 70
                    anchors.verticalCenter: parent.verticalCenter
                    text: title
                    color: root.sumiHi
                    font.family: root.mono
                    font.pixelSize: 13
                    font.letterSpacing: 1
                    font.weight: Font.Medium
                }
                UiText {
                    width: 40
                    anchors.verticalCenter: parent.verticalCenter
                    horizontalAlignment: Text.AlignRight
                    text: secondary
                    color: root.sumiHi
                    font.family: root.mono
                    font.pixelSize: 12
                    font.weight: Font.Medium
                }
            }

            UiText {
                text: primary
                color: root.seal
                font.family: root.mono
                font.pixelSize: 34
                font.weight: Font.Medium
                elide: Text.ElideRight
                width: parent.width
            }

            Sparkline {
                visible: showSparkline
                width: parent.width
                height: 26
                history: parent.parent.history
                tint: root.seal
                base: root.ink
            }

            Item {
                visible: !showSparkline
                width: parent.width
                height: 26
            }

            Column {
                width: parent.width
                spacing: 4

                Row {
                    width: parent.width
                    height: 18
                    spacing: 6

                    UiText {
                        width: 46
                        anchors.verticalCenter: parent.verticalCenter
                        text: bottomLabel
                        color: root.sumiHi
                        font.family: root.mono
                        font.pixelSize: 10
                        font.letterSpacing: 1
                    }

                    Rectangle {
                        width: Math.max(28, parent.width - 46 - 82 - 12)
                        height: 7
                        anchors.verticalCenter: parent.verticalCenter
                        radius: 4
                        color: root.fillIdle
                        opacity: showProgress ? 1 : 0
                        Rectangle {
                            width: parent.width * Math.max(0, Math.min(100, bottomPercent)) / 100
                            height: parent.height
                            radius: 4
                            color: root.seal
                            Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                        }
                    }

                    UiText {
                        width: 82
                        anchors.verticalCenter: parent.verticalCenter
                        horizontalAlignment: Text.AlignRight
                        text: bottomText
                        color: root.ink
                        font.family: root.mono
                        font.pixelSize: 10
                        font.weight: Font.Medium
                        elide: Text.ElideRight
                    }
                }
            }
        }
    }

    component GpuBoardIcon: Canvas {
        width: 19
        height: 14
        property color tint: "white"
        onTintChanged: requestPaint()
        onPaint: {
            var ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)
            ctx.strokeStyle = tint
            ctx.fillStyle = tint
            ctx.lineWidth = 1.35
            ctx.lineCap = "round"
            ctx.lineJoin = "round"

            ctx.strokeRect(2.5, 2.5, 12, 8)
            ctx.beginPath()
            ctx.moveTo(14.5, 4.5)
            ctx.lineTo(17, 4.5)
            ctx.lineTo(17, 8.5)
            ctx.lineTo(14.5, 8.5)
            ctx.stroke()

            ctx.beginPath()
            ctx.arc(6, 6.5, 1.55, 0, Math.PI * 2)
            ctx.arc(11, 6.5, 1.55, 0, Math.PI * 2)
            ctx.stroke()

            ctx.fillRect(4, 11.5, 7, 1)
            ctx.fillRect(3, 0.8, 1.8, 1)
            ctx.fillRect(6, 0.8, 1.8, 1)
            ctx.fillRect(9, 0.8, 1.8, 1)
            ctx.fillRect(12, 0.8, 1.8, 1)
        }
        Component.onCompleted: requestPaint()
    }

    component Sparkline: Canvas {
        property var history: []
        property color tint: "white"
        property color base: "white"
        onHistoryChanged: requestPaint()
        onTintChanged: requestPaint()

        onPaint: {
            var ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)
            ctx.beginPath()
            ctx.moveTo(0, height - 1)
            ctx.lineTo(width, height - 1)
            ctx.strokeStyle = Qt.rgba(base.r, base.g, base.b, 0.12)
            ctx.lineWidth = 1
            ctx.stroke()

            var h = history
            if (h.length < 2) return

            var maxV = 0.25
            for (var n = 0; n < h.length; n++) {
                if (h[n] > maxV) maxV = h[n]
            }
            maxV = Math.min(1, Math.max(0.25, maxV * 1.15))

            ctx.beginPath()
            for (var i = 0; i < h.length; i++) {
                var x = (i / (cpuPanel.maxSamples - 1)) * width
                var y = height - 2 - (h[i] / maxV) * (height - 4)
                if (i === 0) ctx.moveTo(x, y)
                else {
                    var px = ((i - 1) / (cpuPanel.maxSamples - 1)) * width
                    var mx = (px + x) / 2
                    ctx.bezierCurveTo(mx, y, mx, y, x, y)
                }
            }
            ctx.strokeStyle = tint
            ctx.lineWidth = 1.5
            ctx.lineCap = "round"
            ctx.lineJoin = "round"
            ctx.stroke()
        }
    }

    Process {
        id: dataProc
        command: ["bash", "-c",
            "read _ u1 n1 s1 i1 w1 q1 sq1 st1 _ < /proc/stat && " +
            "sleep 0.5 && " +
            "read _ u2 n2 s2 i2 w2 q2 sq2 st2 _ < /proc/stat && " +
            "di=$(( (i2+w2)-(i1+w1) )) && " +
            "dn=$(( (u2+n2+s2+q2+sq2+st2)-(u1+n1+s1+q1+sq1+st1) )) && " +
            "dt=$((di+dn)) && echo CPU_PCT $((dt>0?100*dn/dt:0)); " +
            "cpu_temp(){ best=0; " +
            "for f in /sys/class/hwmon/hwmon*/temp*_input /sys/class/thermal/thermal_zone*/temp; do " +
            "  [ -r \"$f\" ] || continue; dir=${f%/*}; name=$(cat \"$dir/name\" 2>/dev/null); " +
            "  case \"$name\" in amdgpu|nvidia|nouveau) continue;; esac; " +
            "  v=$(cat \"$f\" 2>/dev/null); [ -n \"$v\" ] || continue; [ \"$v\" -gt 1000 ] 2>/dev/null && v=$((v/1000)); " +
            "  [ \"$v\" -ge 20 ] 2>/dev/null && [ \"$v\" -le 120 ] 2>/dev/null || continue; " +
            "  label=${f%_input}_label; label=$(cat \"$label\" 2>/dev/null); " +
            "  echo \"$label $name\" | grep -Eiq 'cpu|package|tctl|tdie|core 0' && { echo \"$v\"; return; }; " +
            "  [ \"$v\" -gt \"$best\" ] 2>/dev/null && best=$v; " +
            "done; echo \"$best\"; }; echo CPU_TEMP $(cpu_temp); " +
            "awk '/MemTotal:/ {t=$2} /MemAvailable:/ {a=$2} END{u=t-a; printf \"RAM %.0f %.0f %.0f\\n\", u, t, (t>0?u*100/t:0)}' /proc/meminfo; " +
            "if command -v nvidia-smi >/dev/null 2>&1; then " +
            "  nvidia-smi --query-gpu=utilization.gpu,temperature.gpu,memory.used,memory.total --format=csv,noheader,nounits 2>/dev/null | " +
            "  awk -F', ' '{printf \"GPU %s %s %s %s\\n\", $1, $2, $3, $4}'; " +
            "elif [ -f /sys/class/drm/card0/device/gpu_busy_percent ]; then " +
            "  read p < /sys/class/drm/card0/device/gpu_busy_percent; " +
            "  t=$(cat /sys/class/drm/card0/device/hwmon/hwmon*/temp1_input 2>/dev/null | head -1); " +
            "  [ -n \"$t\" ] && [ \"$t\" -gt 1000 ] 2>/dev/null && t=$((t/1000)); echo \"GPU $p ${t:-0} 0 0\"; " +
            "elif [ -f /sys/class/hwmon/hwmon2/device/gpu_busy_percent ]; then " +
            "  read p < /sys/class/hwmon/hwmon2/device/gpu_busy_percent; echo \"GPU $p 0 0 0\"; " +
            "fi"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = this.text.trim().split("\n")
                cpuPanel.gpuDriver = ""
                for (var i = 0; i < lines.length; i++) {
                    var parts = lines[i].trim().split(/\s+/)
                    if (parts[0] === "CPU_PCT" && parts.length >= 2) {
                        cpuPanel.cpuPct = parseInt(parts[1]) || 0
                        cpuPanel.cpuHistory = cpuPanel.pushSample(cpuPanel.cpuHistory, cpuPanel.cpuPct)
                    } else if (parts[0] === "CPU_TEMP" && parts.length >= 2) {
                        cpuPanel.cpuTemp = parseInt(parts[1]) || 0
                    } else if (parts[0] === "RAM" && parts.length >= 4) {
                        var usedKB = parseFloat(parts[1]) || 0
                        var totalKB = parseFloat(parts[2]) || 0
                        cpuPanel.ramUsedGiB = usedKB / (1024 * 1024)
                        cpuPanel.ramTotalGiB = totalKB / (1024 * 1024)
                        cpuPanel.ramPct = Math.max(0, Math.min(100, Math.round(parseFloat(parts[3]) || 0)))
                    } else if (parts[0] === "GPU" && parts.length >= 2) {
                        cpuPanel.gpuDriver = "detected"
                        cpuPanel.gpuUtil = parseInt(parts[1]) || 0
                        cpuPanel.gpuTemp = parseInt(parts[2]) || 0
                        cpuPanel.gpuMemUsed = parseInt(parts[3]) || 0
                        cpuPanel.gpuMemTotal = parseInt(parts[4]) || 0
                        cpuPanel.gpuHistory = cpuPanel.pushSample(cpuPanel.gpuHistory, cpuPanel.gpuUtil)
                    }
                }
            }
        }
    }

    Process {
        id: btopRunner
        command: ["bash", "-c", "omarchy-launch-floating-terminal-with-presentation 'btop'"]
    }

    Timer {
        interval: 1500
        running: cpuPanel.visible && root.cpuVisible
        repeat: true
        triggeredOnStart: true
        onTriggered: { dataProc.running = false; dataProc.running = true }
    }
}
