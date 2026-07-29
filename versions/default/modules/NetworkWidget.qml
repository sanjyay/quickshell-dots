import QtQuick
import "../IconMap.js" as IconMap

Item {
    id: rootMod
    required property var root
    property bool compact: false

    readonly property var network: root.network
    readonly property string mode: network.connectionType
    readonly property string ssid: network.connectedSsid
    readonly property string iface: network.interfaceName
    readonly property bool connected: network.connected
    readonly property bool warning: network.needsAttention && network.connected
    readonly property int signal: network.connectedWifi
        ? Math.round((network.connectedWifi.signalStrength || 0) * 100) : 0
    readonly property var wifiIcons: [
        "signal_wifi_0_bar", "network_wifi_1_bar", "network_wifi_2_bar",
        "network_wifi_3_bar", "signal_wifi_4_bar"
    ]
    readonly property string wifiIconName: signal > 0
        ? wifiIcons[Math.min(4, Math.floor(signal / 22))] : "signal_wifi_off"
    readonly property string connectionIconName: mode === "ethernet" ? "lan" : wifiIconName
    readonly property string statusText: !network.installed ? "Unavailable"
        : !network.wifiEnabled && mode === "none" ? "Disabled"
        : warning ? (network.connectivity === "portal" ? "Sign in" : "Limited")
        : mode === "wifi" ? "Connected"
        : mode === "ethernet" ? "Ethernet" : "Disconnected"
    readonly property color stateColor: warning ? root.sealRaw
        : connected ? root.seal
        : Qt.rgba(root.sumi.r, root.sumi.g, root.sumi.b, 0.58)
    readonly property bool shown: root.modNetwork
    readonly property string tooltipText: [
        statusText + (network.connectionName ? " · " + network.connectionName : ""),
        iface ? "Interface: " + iface : "",
        network.ipAddress ? "IP: " + network.ipAddress : "",
        "↓ " + network.formatRate(network.receiveRateBytes)
            + "  ↑ " + network.formatRate(network.transmitRateBytes),
        "Left click: panel · Right click: toggle Wi-Fi · Middle click: refresh"
    ].filter(function(line) { return line !== "" }).join("\n")

    implicitWidth: shown ? 38 : 0
    implicitHeight: 28
    width: implicitWidth
    height: implicitHeight
    visible: implicitWidth > 0.5
    opacity: shown ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: root.pillH
        radius: root.pillRadius
        color: clickArea.containsMouse
            ? Qt.rgba(root.seal.r, root.seal.g, root.seal.b, Math.max(root.pillOpacity, 0.20))
            : root.pill
        border.color: clickArea.containsMouse
            ? Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.42) : root.pillBorder
        border.width: root.pillBorderW
        Behavior on color { ColorAnimation { duration: 120 } }
        Behavior on border.color { ColorAnimation { duration: 120 } }
        PillShadow { theme: root }
    }

    Rectangle {
        anchors.centerIn: parent
        width: 23; height: 23; radius: 12
        color: Qt.rgba(rootMod.stateColor.r, rootMod.stateColor.g,
                       rootMod.stateColor.b,
                       clickArea.containsMouse ? 0.17 : 0.10)
        Behavior on color { ColorAnimation { duration: 120 } }
    }

    IconText {
        anchors.centerIn: parent
        text: IconMap.icon(rootMod.connectionIconName)
        color: rootMod.stateColor
        font.pixelSize: 19
    }

    BarWidgetButton {
        id: clickArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
        onClicked: function(event) {
            if (event.button === Qt.RightButton) network.toggleNetwork()
            else if (event.button === Qt.MiddleButton) network.refresh(true)
            else root.networkVisible = !root.networkVisible
        }
    }
}
