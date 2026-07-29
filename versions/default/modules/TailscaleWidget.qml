import QtQuick
import qs.Commons
import qs.Ui

Item {
    id: rootMod
    required property var root

    readonly property var tailscale: root.tailscale
    readonly property bool shown: root.modTailscale
    readonly property bool connected: tailscale && tailscale.active === true
    readonly property bool loginRequired: tailscale && tailscale.needsLogin === true
    readonly property bool unavailable: tailscale && tailscale.installed === false
    readonly property color contentColor: connected
        ? root.seal
        : (loginRequired
            ? root.urgent
            : (unavailable
                ? Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.28)
                : root.sumi))
    readonly property string tooltipText: unavailable
        ? "Tailscale unavailable"
        : loginRequired
            ? "Tailscale needs login\nleft click: open panel\nright click: toggle\nmiddle click: refresh"
            : connected
                ? "Tailscale connected\nleft click: open panel\nright click: turn off\nmiddle click: refresh"
                : "Tailscale disconnected\nleft click: open panel\nright click: turn on\nmiddle click: refresh"

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

        TailscaleIcon {
            anchors.verticalCenter: parent.verticalCenter
            iconSize: 12
            color: rootMod.contentColor
            crossed: !connected && !loginRequired && !unavailable
            warning: loginRequired
        }
    }

    BarWidgetButton {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
        enabled: rootMod.shown
        Accessible.name: "Tailscale"
        Accessible.description: rootMod.tooltipText
        onClicked: function(mouse) {
            if (mouse.button === Qt.MiddleButton) {
                if (tailscale) tailscale.refresh(true)
                return
            }
            if (mouse.button === Qt.RightButton) {
                if (tailscale) tailscale.toggleTailscale()
                return
            }
            rootMod.root.tailscaleVisible = !rootMod.root.tailscaleVisible
        }
    }
}
