import QtQuick
import Quickshell
import Quickshell.Services.UPower

Item {
    id: rootMod
    required property var root

    // event-driven UPower data — updates instantly on plug / unplug
    readonly property var dev: UPower.displayDevice
    readonly property bool hasBattery: dev !== null && dev.isLaptopBattery
    readonly property int percent: {
        if (!dev) return 0
        var p = dev.percentage
        // robust to either 0..1 or 0..100 reporting
        return Math.round(p <= 1.0 ? p * 100 : p)
    }
    readonly property int devState: dev ? dev.state : UPowerDeviceState.Unknown
    property int lowBatteryThreshold: 20
    property int chargingAnimationSpeed: 1400
    readonly property bool charging: devState === UPowerDeviceState.Charging
    readonly property bool full:     hasBattery && (devState === UPowerDeviceState.FullyCharged || percent >= 100)
    readonly property int displayPercent: full ? 100 : percent
    readonly property bool low:      hasBattery && !charging && !full && percent <= lowBatteryThreshold

    // live time estimates from UPower (seconds); 0 when unknown / not applicable
    readonly property real timeToEmpty: dev ? dev.timeToEmpty : 0
    readonly property real timeToFull:  dev ? dev.timeToFull  : 0
    readonly property string timeText:  charging ? fmtDuration(timeToFull) : fmtDuration(timeToEmpty)
    function fmtDuration(s) {
        if (!s || s <= 0) return ""
        var h = Math.floor(s / 3600)
        var m = Math.floor((s % 3600) / 60)
        return h > 0 ? (h + "h " + m + "m") : (m + "m")
    }

    readonly property string statusText:
        full ? "Full"
        : charging ? "Charging"
        : devState === UPowerDeviceState.Discharging ? "Discharging"
        : "On battery"
    readonly property string tooltipText: statusText + " · " + displayPercent
                                          + (timeText ? " · " + timeText : "")

    // colour shared by the drawn battery body, fill and nub
    readonly property color battColor:
        full ? root.seal
        : charging ? root.indigo
        : (low ? root.seal
        : Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.7))

    readonly property bool shown: hasBattery && root.modBattery

    implicitWidth:  shown ? (row.implicitWidth + 18) : 0
    implicitHeight: 28
    visible: implicitWidth > 0.5
    opacity: shown ? 1 : 0

    Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }


    Rectangle {
        x: 0; anchors.verticalCenter: parent.verticalCenter
        width: Math.round(row.width) + 18
        height: root.pillH
        radius: root.pillRadius
        color: root.pill
        border.color: root.pillBorder
        border.width: root.pillBorderW
        PillShadow { theme: root }
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 0

        // drawn landscape battery — body + stepless fill + terminal nub
        Item {
            id: batt
            width: 41
            height: 16
            anchors.verticalCenter: parent.verticalCenter

            readonly property real ratio: Math.max(0, Math.min(1, rootMod.displayPercent / 100))

            // State animations stay on the icon only: lightweight and easy to tune.
            property real pulse: 1.0
            property real chargeGlow: 0.0
            property real fullGlow: 0.0
            opacity: rootMod.low ? pulse : 1.0
            SequentialAnimation {
                running: rootMod.shown && rootMod.low   // defensive: never animate while hidden / batteryless
                loops: Animation.Infinite
                NumberAnimation { target: batt; property: "pulse"; from: 1.0; to: 0.45; duration: 950; easing.type: Easing.InOutSine }
                NumberAnimation { target: batt; property: "pulse"; from: 0.45; to: 1.0; duration: 950; easing.type: Easing.InOutSine }
            }
            SequentialAnimation {
                running: rootMod.shown && rootMod.charging && !rootMod.full
                loops: Animation.Infinite
                NumberAnimation { target: batt; property: "chargeGlow"; from: 0.18; to: 0.42; duration: rootMod.chargingAnimationSpeed; easing.type: Easing.InOutSine }
                NumberAnimation { target: batt; property: "chargeGlow"; from: 0.42; to: 0.18; duration: rootMod.chargingAnimationSpeed; easing.type: Easing.InOutSine }
            }
            SequentialAnimation {
                running: rootMod.shown && rootMod.full
                loops: Animation.Infinite
                NumberAnimation { target: batt; property: "fullGlow"; from: 0.12; to: 0.26; duration: 1800; easing.type: Easing.InOutSine }
                NumberAnimation { target: batt; property: "fullGlow"; from: 0.26; to: 0.12; duration: 1800; easing.type: Easing.InOutSine }
            }

            Rectangle {
                id: body
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: 36
                height: 15
                radius: 3
                color: rootMod.full
                    ? Qt.rgba(root.seal.r, root.seal.g, root.seal.b, batt.fullGlow)
                    : (rootMod.charging ? Qt.rgba(root.indigo.r, root.indigo.g, root.indigo.b, batt.chargeGlow) : "transparent")
                border.width: 1.2
                border.color: rootMod.battColor
                Behavior on color { ColorAnimation { duration: 180 } }
                Behavior on border.color { ColorAnimation { duration: 200 } }

                // faint indigo wash so a charging cell reads "active" at any level
                Rectangle {
                    visible: rootMod.charging
                    anchors.fill: parent
                    anchors.margins: 1.8
                    radius: 1.2
                    color: Qt.rgba(root.indigo.r, root.indigo.g, root.indigo.b, 0.28)
                }

                Rectangle {
                    id: fill
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    anchors.margins: 1.8
                    width: Math.max(batt.ratio > 0 ? 1.5 : 0, (parent.width - 3.6) * batt.ratio)
                    radius: 1.2
                    clip: true
                    color: rootMod.battColor
                    Behavior on width { NumberAnimation { duration: 350; easing.type: Easing.OutCubic } }
                    Behavior on color { ColorAnimation { duration: 200 } }

                    // font-free charging shimmer that sweeps across the fill
                    Rectangle {
                        visible: rootMod.charging && !rootMod.full
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: 6
                        radius: parent.radius
                        color: Qt.rgba(1, 1, 1, 0.18)
                        property real pos: 0
                        x: (parent.width + width) * pos - width
                        SequentialAnimation on pos {
                            running: rootMod.charging && !rootMod.full
                            loops: Animation.Infinite
                            NumberAnimation { from: 0; to: 1; duration: rootMod.chargingAnimationSpeed; easing.type: Easing.InOutSine }
                            PauseAnimation { duration: Math.round(rootMod.chargingAnimationSpeed * 0.35) }
                        }
                    }
                }

                UiText {
                    anchors.centerIn: parent
                    text: rootMod.displayPercent
                    color: rootMod.displayPercent >= 45
                        ? root.paper
                        : Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.9)
                    font.family: root.mono
                    font.pixelSize: 9
                    font.bold: true
                    Behavior on color { ColorAnimation { duration: 200 } }
                }
            }

            // terminal nub (positive pole)
            Rectangle {
                anchors.left: body.right
                anchors.leftMargin: -0.5
                anchors.verticalCenter: parent.verticalCenter
                width: 4
                height: 7
                radius: 1.2
                color: rootMod.battColor
                Behavior on color { ColorAnimation { duration: 200 } }
            }
        }
    }

    TooltipMixin { id: tip; root: rootMod.root; owner: rootMod; text: rootMod.tooltipText }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true; cursorShape: Qt.PointingHandCursor
        onEntered: { if (rootMod.hasBattery) tip.show() }
        onExited:  { tip.hide() }
        onClicked: { tip.hide(); root.batteryVisible = !root.batteryVisible }
    }
}
