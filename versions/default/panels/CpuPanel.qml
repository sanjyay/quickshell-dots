import QtQuick
import "../modules"
import Quickshell
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

    readonly property var metricsModel: root.systemMetrics
    readonly property int cpuPct: metricsModel.cpuPercent
    readonly property int cpuTemp: metricsModel.cpuTemperature
    readonly property real cpuClockGHz: metricsModel.cpuClockGHz
    readonly property int cpuCores: metricsModel.cpuCores
    readonly property int cpuThreads: metricsModel.cpuThreads
    readonly property string gpuDriver: metricsModel.gpuProvider
    readonly property int gpuUtil: metricsModel.gpuUsagePercent === null ? 0 : metricsModel.gpuUsagePercent
    readonly property int gpuTemp: metricsModel.gpuTemperatureC === null ? 0 : metricsModel.gpuTemperatureC
    readonly property int gpuMemUsed: metricsModel.gpuVramUsedMiB === null ? 0 : metricsModel.gpuVramUsedMiB
    readonly property int gpuMemTotal: metricsModel.gpuVramTotalMiB === null ? 0 : metricsModel.gpuVramTotalMiB
    readonly property bool gpuMemAvailable: metricsModel.gpuVramUsedMiB !== null && metricsModel.gpuVramTotalMiB !== null
    readonly property int gpuClockMHz: metricsModel.gpuClockMHz === null ? 0 : metricsModel.gpuClockMHz
    readonly property real gpuPowerW: metricsModel.gpuPowerWatts === null ? -1 : metricsModel.gpuPowerWatts
    readonly property bool hasGpu: metricsModel.gpuDisplayModelReady
    readonly property int ramPct: metricsModel.ramPercent
    readonly property real ramUsedGiB: metricsModel.ramUsedGiB
    readonly property real ramTotalGiB: metricsModel.ramTotalGiB

    function tempText(v) {
        return v > 0 ? v + "\u00B0C" : "--\u00B0C"
    }

    function mibToGib(v) {
        return (Math.max(0, v) / 1024).toFixed(1)
    }

    function powerText(v) {
        return v >= 0 ? v.toFixed(1) + " W" : "--"
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

}
