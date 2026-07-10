import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: rootMod
    required property var root

    visible: implicitWidth > 0.5
    implicitWidth: root.modCpu ? row.implicitWidth + 18 : 0
    implicitHeight: 28
    width: implicitWidth
    height: implicitHeight
    opacity: root.modCpu ? 1 : 0
    Behavior on opacity      { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

    property int percent: 0
    property int cpuTemp: 0
    property int gpuTemp: 0
    property bool hasGpu: false
    property var history: []
    readonly property int maxSamples: 30
    readonly property string cpuIcon: "\uf2db"
    readonly property string tooltipText: "CPU " + tempText(cpuTemp, true) + (hasGpu ? " · GPU " + tempText(gpuTemp, true) : "")

    function tempText(v, withC) {
        return v > 0 ? (v + "\u00B0" + (withC ? "C" : "")) : "--\u00B0"
    }
    function gpuProbeCommand() {
        return "p=\"$HOME/.config/quickshell/bar/modules/qs-gpu-probe.sh\"; " +
               "[ -x \"$p\" ] || p=\"versions/default/modules/qs-gpu-probe.sh\"; " +
               "\"$p\""
    }

    Rectangle {
        x: 0; anchors.verticalCenter: parent.verticalCenter
        width: Math.round(row.width) + 18
        height: root.pillH
        radius: root.pillRadius
        color: clickArea.containsMouse ? Qt.rgba(root.seal.r, root.seal.g, root.seal.b, Math.max(root.pillOpacity, 0.24)) : root.pill
        border.color: root.pillBorder
        border.width: root.pillBorderW
        Behavior on color { ColorAnimation { duration: 120 } }
        PillShadow { theme: root }
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 10

        UiText {
            anchors.verticalCenter: parent.verticalCenter
            text: rootMod.cpuIcon
            color: root.seal
            font.family: root.mono
            font.pixelSize: 15
        }

        UiText {
            anchors.verticalCenter: parent.verticalCenter
            text: rootMod.tempText(rootMod.cpuTemp, false)
            color: root.seal
            font.family: root.mono
            font.pixelSize: 12
            font.weight: Font.Medium
        }

        Rectangle {
            width: 1
            height: 14
            radius: 1
            anchors.verticalCenter: parent.verticalCenter
            color: root.sep
        }

        GpuBoardIcon {
            anchors.verticalCenter: parent.verticalCenter
            tint: root.seal
        }

        UiText {
            anchors.verticalCenter: parent.verticalCenter
            text: rootMod.tempText(rootMod.gpuTemp, false)
            color: root.seal
            font.family: root.mono
            font.pixelSize: 12
            font.weight: Font.Medium
        }
    }

    Process {
        id: cpuProc
        command: ["bash", "-c",
            "read _ u1 n1 s1 i1 w1 q1 sq1 st1 _ < /proc/stat && " +
            "sleep 0.5 && " +
            "read _ u2 n2 s2 i2 w2 q2 sq2 st2 _ < /proc/stat && " +
            "di=$(( (i2+w2)-(i1+w1) )) && " +
            "dn=$(( (u2+n2+s2+q2+sq2+st2)-(u1+n1+s1+q1+sq1+st1) )) && " +
            "dt=$((di+dn)) && " +
            "echo CPU_PCT $((dt>0?100*dn/dt:0)); " +
            "cpu_temp(){ best=0; " +
            "for f in /sys/class/hwmon/hwmon*/temp*_input /sys/class/thermal/thermal_zone*/temp; do " +
            "  [ -r \"$f\" ] || continue; dir=${f%/*}; name=$(cat \"$dir/name\" 2>/dev/null); " +
            "  case \"$name\" in amdgpu|nvidia|nouveau) continue;; esac; " +
            "  v=$(cat \"$f\" 2>/dev/null); [ -n \"$v\" ] || continue; [ \"$v\" -gt 1000 ] 2>/dev/null && v=$((v/1000)); " +
            "  [ \"$v\" -ge 20 ] 2>/dev/null && [ \"$v\" -le 120 ] 2>/dev/null || continue; " +
            "  label=${f%_input}_label; label=$(cat \"$label\" 2>/dev/null); " +
            "  echo \"$label $name\" | grep -Eiq 'cpu|package|tctl|tdie|core 0' && { echo \"$v\"; return; }; " +
            "  [ \"$v\" -gt \"$best\" ] 2>/dev/null && best=$v; " +
            "done; echo \"$best\"; }; " +
            "echo CPU_TEMP $(cpu_temp); " +
            rootMod.gpuProbeCommand()
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = this.text.trim().split("\n")
                for (var i = 0; i < lines.length; i++) {
                    var parts = lines[i].trim().split(/\s+/)
                    if (parts[0] === "GPU" && parts.length >= 4) {
                        rootMod.hasGpu = parts[1] !== "none"
                        rootMod.gpuTemp = parts[3] === "--" ? 0 : Math.max(0, parseInt(parts[3]) || 0)
                        continue
                    }
                    var v = parseInt(parts[1])
                    if (isNaN(v)) continue
                    if (parts[0] === "CPU_PCT") {
                        rootMod.percent = Math.max(0, Math.min(100, v))
                        var h = rootMod.history.slice()
                        h.push(rootMod.percent / 100)
                        if (h.length > rootMod.maxSamples) h.shift()
                        rootMod.history = h
                    } else if (parts[0] === "CPU_TEMP") {
                        rootMod.cpuTemp = Math.max(0, v)
                    }
                }
            }
        }
    }

    Timer {
        interval: 2000; running: root.modCpu; repeat: true; triggeredOnStart: true
        onTriggered: { cpuProc.running = false; cpuProc.running = true }
    }

    TooltipMixin { id: tip; root: rootMod.root; owner: rootMod; text: rootMod.tooltipText }

    BarWidgetButton {
        id: clickArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onEntered: tip.show()
        onExited: { tip.hide() }
        onClicked: { tip.hide(); root.cpuVisible = !root.cpuVisible }
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
}
