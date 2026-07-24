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
    readonly property string cpuIcon: "\uf2db"
    readonly property string ramIcon: "\uf538"

    property int cpuPct: 0
    property int cpuTemp: 0
    property real cpuClockGHz: 0
    property int cpuCores: 0
    property int cpuThreads: 0
    property string gpuDriver: ""
    property int gpuUtil: 0
    property int gpuTemp: 0
    property int gpuMemUsed: 0
    property int gpuMemTotal: 0
    property bool gpuMemAvailable: false
    property int gpuClockMHz: 0
    property real gpuPowerW: -1
    property string gpuSource: ""
    readonly property bool hasGpu: gpuDriver !== "" && gpuDriver !== "none"
    property int ramPct: 0
    property real ramUsedGiB: 0.0
    property real ramTotalGiB: 0.0

    function tempText(v) {
        return v > 0 ? v + "\u00B0C" : "--\u00B0C"
    }

    function mibToGib(v) {
        return (Math.max(0, v) / 1024).toFixed(1)
    }

    function powerText(v) {
        return v >= 0 ? v.toFixed(1) + " W" : "--"
    }
    function gpuProbeCommand(debug) {
        return "p=\"$HOME/.config/quickshell/bar/modules/qs-gpu-probe.sh\"; " +
               "[ -x \"$p\" ] || p=\"versions/default/modules/qs-gpu-probe.sh\"; " +
               "\"$p\"" + (debug ? " --debug" : "")
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
        width: 610
        height: 172
        radius: reveal > 0.001 ? root.pillRadius : 0
        color: Qt.rgba(root.bg.r, root.bg.g, root.bg.b, 0.96)
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

        Rectangle {
            id: anchorNotch
            width: 10
            height: 10
            rotation: 45
            color: card.color
            border.color: root.pillBorder
            border.width: root.pillBorderW
            x: Math.max(18, Math.min(card.width - width - 18, root.cpuBarX - card.x - width / 2))
            y: root.barPosition === "bottom" ? card.height - height / 2 : -height / 2
        }

        Column {
            id: col
            anchors.fill: parent
            anchors.margins: 16
            spacing: 10

            Row {
                width: parent.width
                height: 140
                spacing: 0

                MonitorColumn {
                    root: cpuPanel.root
                    width: (parent.width - 2) / 3
                    height: parent.height
                    title: "CPU"
                    primary: cpuPanel.tempText(cpuPanel.cpuTemp)
                    usagePercent: cpuPanel.cpuPct
                    metrics: [
                        { label: "Clock", value: cpuPanel.cpuClockGHz > 0 ? cpuPanel.cpuClockGHz.toFixed(2) + " GHz" : "--" },
                        { label: "Cores", value: cpuPanel.cpuCores > 0 ? cpuPanel.cpuCores + "C / " + cpuPanel.cpuThreads + "T" : "--" }
                    ]
                }

                Rectangle { width: 1; height: parent.height; color: root.sep }

                MonitorColumn {
                    root: cpuPanel.root
                    width: (parent.width - 2) / 3
                    height: parent.height
                    title: "GPU"
                    primary: cpuPanel.hasGpu ? cpuPanel.tempText(cpuPanel.gpuTemp) : "--\u00B0C"
                    usagePercent: cpuPanel.hasGpu ? cpuPanel.gpuUtil : 0
                    metrics: [
                        { label: "VRAM", value: cpuPanel.gpuMemAvailable && cpuPanel.gpuMemTotal > 0
                            ? cpuPanel.mibToGib(cpuPanel.gpuMemUsed) + "/" + cpuPanel.mibToGib(cpuPanel.gpuMemTotal) + " GiB" : "--" },
                        { label: "Clock", value: cpuPanel.gpuClockMHz > 0 ? cpuPanel.gpuClockMHz + " MHz" : "--" },
                        { label: "Power", value: cpuPanel.powerText(cpuPanel.gpuPowerW) }
                    ]
                }

                Rectangle { width: 1; height: parent.height; color: root.sep }

                MonitorColumn {
                    root: cpuPanel.root
                    width: (parent.width - 2) / 3
                    height: parent.height
                    title: "RAM"
                    primary: cpuPanel.ramUsedGiB.toFixed(1) + " GiB"
                    usagePercent: cpuPanel.ramPct
                    metrics: [
                        { label: "Used", value: cpuPanel.ramUsedGiB.toFixed(1) + " GiB" },
                        { label: "Total", value: cpuPanel.ramTotalGiB.toFixed(1) + " GiB" },
                        { label: "Available", value: Math.max(0, cpuPanel.ramTotalGiB - cpuPanel.ramUsedGiB).toFixed(1) + " GiB" }
                    ]
                }
            }
        }
    }

    component MonitorColumn: Item {
        required property var root
        property string title: ""
        property string primary: ""
        property real usagePercent: 0
        property var metrics: []

        Column {
            anchors.fill: parent
            anchors.leftMargin: 14
            anchors.rightMargin: 14
            spacing: 5

            UiText {
                text: title
                color: root.sumiHi
                font.family: root.mono
                font.pixelSize: 11
                font.letterSpacing: 1.5
                font.weight: Font.Medium
            }

            UiText {
                text: primary
                color: root.seal
                font.family: root.mono
                font.pixelSize: 28
                font.weight: Font.Medium
                elide: Text.ElideRight
                width: parent.width
            }

            Row {
                width: parent.width
                height: 13
                spacing: 8
                UiText {
                    width: 34
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Usage"
                    color: root.sumiHi
                    font.family: root.mono
                    font.pixelSize: 9
                }
                Rectangle {
                    width: parent.width - 42
                    height: 4
                    anchors.verticalCenter: parent.verticalCenter
                    radius: 2
                    color: root.fillIdle
                    Rectangle {
                        width: parent.width * Math.max(0, Math.min(100, usagePercent)) / 100
                        height: parent.height
                        radius: 2
                        color: root.seal
                        Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                    }
                }
            }

            Repeater {
                model: metrics
                Item {
                    required property var modelData
                    width: parent.width
                    height: 14
                    UiText {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.label
                        color: root.sumiHi
                        font.family: root.mono
                        font.pixelSize: 9
                    }
                    UiText {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.value
                        color: root.ink
                        font.family: root.mono
                        font.pixelSize: 9
                        font.weight: Font.Medium
                    }
                }
            }

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
            "awk -F: '/cpu MHz/ {sum+=$2; n++} END{printf \"CPU_CLOCK %.0f\\n\", n?sum/n:0}' /proc/cpuinfo; " +
            "threads=$(nproc 2>/dev/null || echo 0); " +
            "cores=$(awk '/^physical id/ {p=$4} /^core id/ {print p \":\" $4}' /proc/cpuinfo 2>/dev/null | sort -u | wc -l); " +
            "[ \"$cores\" -gt 0 ] 2>/dev/null || cores=$(awk -F: '/^cpu cores/ {gsub(/ /,\"\",$2); print $2; exit}' /proc/cpuinfo); " +
            "echo CPU_TOPOLOGY ${cores:-0} ${threads:-0}; " +
            "awk '/MemTotal:/ {t=$2} /MemAvailable:/ {a=$2} END{u=t-a; printf \"RAM %.0f %.0f %.0f\\n\", u, t, (t>0?u*100/t:0)}' /proc/meminfo; " +
            cpuPanel.gpuProbeCommand(false)
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = this.text.trim().split("\n")
                cpuPanel.gpuDriver = ""
                cpuPanel.gpuSource = ""
                cpuPanel.gpuMemAvailable = false
                for (var i = 0; i < lines.length; i++) {
                    var parts = lines[i].trim().split(/\s+/)
                    if (parts[0] === "CPU_PCT" && parts.length >= 2) {
                        cpuPanel.cpuPct = parseInt(parts[1]) || 0
                    } else if (parts[0] === "CPU_TEMP" && parts.length >= 2) {
                        cpuPanel.cpuTemp = parseInt(parts[1]) || 0
                    } else if (parts[0] === "CPU_CLOCK" && parts.length >= 2) {
                        cpuPanel.cpuClockGHz = (parseFloat(parts[1]) || 0) / 1000
                    } else if (parts[0] === "CPU_TOPOLOGY" && parts.length >= 3) {
                        cpuPanel.cpuCores = parseInt(parts[1]) || 0
                        cpuPanel.cpuThreads = parseInt(parts[2]) || 0
                    } else if (parts[0] === "RAM" && parts.length >= 4) {
                        var usedKB = parseFloat(parts[1]) || 0
                        var totalKB = parseFloat(parts[2]) || 0
                        cpuPanel.ramUsedGiB = usedKB / (1024 * 1024)
                        cpuPanel.ramTotalGiB = totalKB / (1024 * 1024)
                        cpuPanel.ramPct = Math.max(0, Math.min(100, Math.round(parseFloat(parts[3]) || 0)))
                    } else if (parts[0] === "GPU" && parts.length >= 6) {
                        cpuPanel.gpuDriver = parts[1]
                        cpuPanel.gpuUtil = parts[2] === "--" ? 0 : (parseInt(parts[2]) || 0)
                        cpuPanel.gpuTemp = parts[3] === "--" ? 0 : (parseInt(parts[3]) || 0)
                        cpuPanel.gpuMemAvailable = parts[4] !== "--" && parts[5] !== "--"
                        cpuPanel.gpuMemUsed = cpuPanel.gpuMemAvailable ? (parseInt(parts[4]) || 0) : 0
                        cpuPanel.gpuMemTotal = cpuPanel.gpuMemAvailable ? (parseInt(parts[5]) || 0) : 0
                        cpuPanel.gpuClockMHz = parts.length >= 7 && parts[6] !== "--" ? (parseInt(parts[6]) || 0) : 0
                        cpuPanel.gpuPowerW = parts.length >= 8 && parts[7] !== "--" ? (parseFloat(parts[7]) || -1) : -1
                    }
                }
            }
        }
    }

    Timer {
        interval: 1500
        running: cpuPanel.visible && root.cpuVisible
        repeat: true
        triggeredOnStart: true
        onTriggered: { dataProc.running = false; dataProc.running = true }
    }
}
