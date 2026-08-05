import QtQuick
import Quickshell

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

    readonly property int percent: root.systemMetrics.cpuPercent
    readonly property int cpuTemp: root.systemMetrics.cpuTemperature
    readonly property int gpuTemp: root.systemMetrics.gpuTemperatureC === null ? 0 : root.systemMetrics.gpuTemperatureC
    readonly property bool hasGpu: root.systemMetrics.gpuDisplayModelReady
    readonly property var history: root.systemMetrics.cpuHistory
    readonly property string cpuIcon: "\uf2db"
    readonly property string tooltipText: "CPU " + tempText(cpuTemp, true) + (hasGpu ? " · GPU " + tempText(gpuTemp, true) : "")

    function tempText(v, withC) {
        return v > 0 ? (v + "\u00B0" + (withC ? "C" : "")) : "--\u00B0"
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
            font.pixelSize: root.uiFontSize(12)
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
            font.pixelSize: root.uiFontSize(12)
            font.weight: Font.Medium
        }
    }

    BarWidgetButton {
        id: clickArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: { root.cpuVisible = !root.cpuVisible }
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
