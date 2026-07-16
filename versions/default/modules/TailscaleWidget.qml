import QtQuick
import Quickshell.Io

Item {
    id: rootMod
    required property var root

    readonly property bool shown: root.modTailscale
    readonly property bool connected: root.tailscaleStatus === "connected"
    readonly property bool unavailable: root.tailscaleStatus === "unavailable"
    property bool toggleInFlight: false
    readonly property color contentColor: connected
        ? root.seal
        : (unavailable
            ? Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.28)
            : root.sumi)

    visible: implicitWidth > 0.5
    implicitWidth: shown ? row.implicitWidth + 16 : 0
    implicitHeight: 28
    width: implicitWidth
    height: implicitHeight
    opacity: shown ? 1 : 0

    Behavior on implicitWidth { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
    Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

    Rectangle {
        anchors.centerIn: parent
        width: Math.round(row.implicitWidth) + 16
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
        spacing: 5

        UiText {
            anchors.verticalCenter: parent.verticalCenter
            text: "TS"
            color: rootMod.contentColor
            font.family: root.mono
            font.pixelSize: 11
            font.weight: Font.Medium
        }

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 7; height: 7; radius: 3.5
            color: rootMod.contentColor
            border.color: rootMod.connected ? root.seal : root.sep
            border.width: 1
            Behavior on color { ColorAnimation { duration: 180 } }
        }
    }

    Process {
        id: tailscaleToggleProc
        running: false
        onExited: {
            rootMod.toggleInFlight = false
            rootMod.root.refreshTailscale()
        }
    }

    function toggleConnection() {
        if (toggleInFlight || unavailable) return
        toggleInFlight = true
        tailscaleToggleProc.command = connected
            ? ["tailscale", "down"]
            : ["tailscale", "up"]
        tailscaleToggleProc.running = true
    }

    BarWidgetButton {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        enabled: rootMod.shown
        Accessible.name: "Tailscale status"
        Accessible.description: rootMod.connected ? "Connected" : "Disconnected"
        onClicked: function(mouse) {
            if (mouse.button === Qt.RightButton) {
                rootMod.root.tailscaleVisible = !rootMod.root.tailscaleVisible
                return
            }
            rootMod.toggleConnection()
        }
    }
}
