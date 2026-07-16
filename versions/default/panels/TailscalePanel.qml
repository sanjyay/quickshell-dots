import QtQuick
import Quickshell
import Quickshell.Wayland
import "../modules"

PanelWindow {
    id: panel
    required property var root

    screen: root.activePopupScreen
    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-tailscale-info"
    WlrLayershell.keyboardFocus: root.tailscaleVisible
        ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    readonly property int barExtent: 35
    readonly property int gap: 8
    property real reveal: root.tailscaleVisible ? 1 : 0

    Behavior on reveal {
        NumberAnimation {
            duration: root.tailscaleVisible ? 160 : 120
            easing.type: root.tailscaleVisible ? Easing.OutCubic : Easing.InCubic
        }
    }

    visible: reveal > 0.001

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: root.tailscaleVisible = false
    }

    Rectangle {
        id: card
        width: 300
        height: content.implicitHeight + 24
        radius: reveal > 0.001 ? root.pillRadius : 0
        color: root.bg
        border.color: root.pillBorder
        border.width: root.pillBorderW
        opacity: panel.reveal
        scale: 0.97 + panel.reveal * 0.03
        transformOrigin: root.barPosition === "bottom" ? Item.Bottom : Item.Top
        x: Math.round(Math.max(6, Math.min(root.tailscaleBarX - width / 2, parent.width - width - 6)))
        y: root.barPosition === "bottom"
            ? parent.height - panel.barExtent - panel.gap - height
            : panel.barExtent + panel.gap
        focus: root.tailscaleVisible

        PillShadow { theme: root }

        Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Escape) {
                root.tailscaleVisible = false
                event.accepted = true
            }
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: function(mouse) { mouse.accepted = true }
        }

        Column {
            id: content
            anchors.fill: parent
            anchors.margins: 12
            spacing: 9

            Item {
                width: parent.width
                height: 24

                Row {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 8; height: 8; radius: 4
                        color: root.tailscaleStatus === "connected" ? root.seal : root.sumi
                        border.color: root.tailscaleStatus === "connected" ? root.seal : root.sep
                        border.width: 1
                    }

                    UiText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Tailscale"
                        color: root.ink
                        font.family: root.mono
                        font.pixelSize: 13
                        font.weight: Font.Medium
                        font.letterSpacing: 1.5
                    }
                }

                UiText {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.tailscaleStatus === "connected" ? "Connected"
                        : root.tailscaleStatus === "login-required" ? "Login required"
                        : root.tailscaleStatus === "unavailable" ? "Unavailable" : "Disconnected"
                    color: root.tailscaleStatus === "connected" ? root.seal : root.sumi
                    font.family: root.mono
                    font.pixelSize: 10
                }
            }

            Rectangle { width: parent.width; height: 1; color: root.sep }

            InfoRow { label: "Device"; value: root.tailscaleHostName || "—" }
            InfoRow { label: "Address"; value: root.tailscaleAddress || "—" }
            InfoRow { label: "Tailnet"; value: root.tailscaleTailnet || "—" }
            InfoRow {
                label: "Peers online"
                value: root.tailscaleAvailable ? String(root.tailscalePeerCount) : "—"
            }
            InfoRow { label: "Backend"; value: root.tailscaleBackendState || "Unknown" }
        }
    }

    component InfoRow: Item {
        required property string label
        required property string value
        width: content.width
        height: 18

        UiText {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: parent.label
            color: root.sumi
            font.family: root.mono
            font.pixelSize: 10
        }

        UiText {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: Math.max(80, parent.width - 105)
            horizontalAlignment: Text.AlignRight
            text: parent.value
            color: root.ink
            font.family: root.mono
            font.pixelSize: 10
            elide: Text.ElideRight
        }
    }
}
