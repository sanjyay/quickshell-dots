import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../IconMap.js" as IconMap
import "../modules"

PanelWindow {
    id: panel
    required property var root

    readonly property var network: root.network
    property real reveal: root.networkVisible ? 1 : 0
    property int selectedIndex: network.nearbyNetworks.length > 0 ? 0 : -1
    property int dnsIndex: Math.max(0, dnsProviders.indexOf(network.dnsMode))
    property string focusSection: "wifi"
    property string passwordSsid: ""
    property string passwordText: ""
    property bool revealPassword: false
    property bool customDnsOpen: false
    property string customDnsText: ""
    property var passwordNetwork: null
    property int phraseIndex: 0
    readonly property var dnsProviders: ["DHCP", "Cloudflare", "Google", "Custom"]
    readonly property var phrases: [
        "ROUTING CRUMBS", "HANDLING PACKETS", "SORTING FRAMES",
        "HAULING BYTES", "BENDING LIGHT"
    ]

    screen: root.activePopupScreen
    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-rise-network"
    WlrLayershell.keyboardFocus: root.networkVisible
        ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    visible: reveal > 0.001

    Behavior on reveal {
        NumberAnimation {
            duration: root.networkVisible ? 160 : 120
            easing.type: root.networkVisible ? Easing.OutCubic : Easing.InCubic
        }
    }

    function closePanel() {
        passwordSsid = ""
        passwordText = ""
        passwordNetwork = null
        revealPassword = false
        customDnsOpen = false
        root.networkVisible = false
    }

    function headerDetail() {
        if (network.connectionType === "ethernet" && network.connectionSpeedMbps > 0) {
            var speed = network.connectionSpeedMbps
            return speed >= 1000 ? (speed / 1000).toFixed(speed % 1000 === 0 ? 0 : 1)
                + "gbit" : speed + "mbit"
        }
        if (network.connectionType === "wifi" && network.wifiFrequencyMHz > 0) {
            var frequency = network.wifiFrequencyMHz
            if (frequency >= 5925) return "6 GHz"
            if (frequency >= 4900) return "5 GHz"
            return "2.4 GHz"
        }
        return ""
    }

    function headerTitle() {
        if (!network.installed) return "Network unavailable"
        if (!network.wifiEnabled && !network.connected) return "Networking disabled"
        var title = network.connectionType === "ethernet" ? "Ethernet"
            : network.connectionType === "wifi" ? (network.connectedSsid || "Wi-Fi")
            : network.needsAttention ? "Limited connectivity" : "Disconnected"
        var detail = headerDetail()
        return detail === "" ? title : title + " (" + detail + ")"
    }

    function iconName() {
        if (network.connectionType === "ethernet") return "lan"
        return network.connected ? "signal_wifi_4_bar" : "signal_wifi_off"
    }

    function metric(value, suffix, decimals) {
        if (value < 0 || !isFinite(value)) return "Unavailable"
        return Number(value).toFixed(decimals) + suffix
    }

    function wifiIcon(strength) {
        if (strength >= 75) return "signal_wifi_4_bar"
        if (strength >= 50) return "network_wifi_3_bar"
        if (strength >= 25) return "network_wifi_2_bar"
        return "network_wifi_1_bar"
    }

    function selectedNetwork() {
        if (selectedIndex < 0 || selectedIndex >= network.nearbyNetworks.length) return null
        return network.nearbyNetworks[selectedIndex]
    }

    function activateNetwork(entry) {
        if (!entry || network.busy) return
        if (entry.enterprise) {
            network.lastError = "Enterprise Wi-Fi requires the Omarchy network manager"
            network.lastErrorCode = "enterprise-wifi-unsupported"
            return
        }
        if (entry.secured && !entry.known) {
            passwordSsid = entry.ssid
            passwordNetwork = entry
            passwordText = ""
            revealPassword = false
            Qt.callLater(function() { passwordInput.forceActiveFocus() })
            return
        }
        network.connectNetwork(entry, "")
    }

    function submitPassword() {
        var entry = passwordNetwork
        if (!entry || entry.ssid !== passwordSsid || passwordText === "") return
        var secret = passwordText
        passwordText = ""
        passwordSsid = ""
        passwordNetwork = null
        network.connectNetwork(entry, secret)
        secret = ""
        card.forceActiveFocus()
    }

    function activateDns(provider) {
        if (provider === "Custom") {
            network.runCustomDns("")
            closePanel()
        } else {
            network.setDns(provider)
            // Match Quattro: release the exclusive panel focus immediately so
            // the system polkit authentication dialog can receive input.
            closePanel()
        }
    }

    function submitCustomDns() {
        if (!network.validCustomDns(customDnsText)) return
        var value = customDnsText
        customDnsText = ""
        customDnsOpen = false
        network.runCustomDns(value)
        card.forceActiveFocus()
    }

    function moveSelection(delta) {
        focusSection = "wifi"
        if (network.nearbyNetworks.length === 0) {
            selectedIndex = -1
            return
        }
        selectedIndex = Math.max(0, Math.min(network.nearbyNetworks.length - 1,
            (selectedIndex < 0 ? 0 : selectedIndex) + delta))
        networkList.positionViewAtIndex(selectedIndex, ListView.Contain)
    }

    onVisibleChanged: if (visible) {
        selectedIndex = network.nearbyNetworks.length > 0 ? 0 : -1
        dnsIndex = Math.max(0, dnsProviders.indexOf(network.dnsMode))
        network.refresh(true)
        Qt.callLater(function() { card.forceActiveFocus() })
    }

    Connections {
        target: network
        function onNearbyNetworksChanged() {
            if (network.nearbyNetworks.length === 0) panel.selectedIndex = -1
            else if (panel.selectedIndex < 0
                     || panel.selectedIndex >= network.nearbyNetworks.length)
                panel.selectedIndex = 0
        }
    }

    Timer {
        interval: 2800
        running: root.networkVisible && network.connected
        repeat: true
        onTriggered: panel.phraseIndex = (panel.phraseIndex + 1) % panel.phrases.length
    }

    IpcHandler {
        target: "quickshell-rise-network"
        function open(): string {
            root.activateFocusedPopupScreen()
            root.networkVisible = true
            return "opened"
        }
        function close(): string { panel.closePanel(); return "closed" }
        function refresh(): string { network.refresh(true); return "refreshing" }
        function speedTest(): string {
            if (!network.speedTestAvailable || !network.connected) return "unavailable"
            network.runSpeedTest()
            return "started"
        }
        function setDns(provider: string): string {
            if (["DHCP", "Cloudflare", "Google"].indexOf(provider) < 0)
                return "invalid-provider"
            network.setDns(provider)
            return network.dnsBusy ? "started" : "unavailable"
        }
        function state(): string {
            return JSON.stringify({
                visible: root.networkVisible,
                connected: network.connected,
                connectionType: network.connectionType,
                interfaceName: network.interfaceName,
                connectivity: network.connectivity,
                nearbyNetworkCount: network.nearbyNetworks.length,
                dnsMode: network.dnsMode,
                dnsBusy: network.dnsBusy,
                scanning: network.scanning,
                speedTestRunning: network.speedTestRunning,
                speedTestPhase: network.speedTestPhase,
                speedTestDownloadMbps: network.speedTestDownloadMbps,
                speedTestUploadMbps: network.speedTestUploadMbps,
                speedTestError: network.speedTestError
            })
        }
    }

    MouseArea { anchors.fill: parent; onClicked: panel.closePanel() }

    Rectangle {
        id: card
        width: Math.min(390, panel.width - 12)
        height: Math.min(content.implicitHeight + 24, panel.height - 92)
        x: Math.round(Math.max(6, Math.min(
            root.networkBarX - width / 2, panel.width - width - 6)))
        y: root.barPosition === "bottom"
            ? panel.height - 35 - 8 - height : 35 + 8
        radius: panel.reveal > 0.001 ? root.pillRadius : 0
        color: root.bg
        border.color: root.pillBorder
        border.width: root.pillBorderW
        opacity: panel.reveal
        focus: root.networkVisible
        clip: true
        PillShadow { theme: root }

        Keys.onPressed: function(event) {
            if (passwordSsid !== "" || customDnsOpen) {
                if (event.key === Qt.Key_Escape) {
                    passwordSsid = ""
                    passwordText = ""
                    passwordNetwork = null
                    customDnsOpen = false
                    customDnsText = ""
                    card.forceActiveFocus()
                    event.accepted = true
                }
                return
            }
            if (event.key === Qt.Key_Escape) closePanel()
            else if (event.key === Qt.Key_Down || event.key === Qt.Key_J) moveSelection(1)
            else if (event.key === Qt.Key_Up || event.key === Qt.Key_K) moveSelection(-1)
            else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter
                     || event.key === Qt.Key_Space) activateNetwork(selectedNetwork())
            else if (event.key === Qt.Key_R) network.refresh(true)
            else if (event.key === Qt.Key_S) network.runSpeedTest()
            else if (event.key === Qt.Key_D) focusSection = "dns"
            else if (event.key === Qt.Key_T) network.toggleNetwork()
            else return
            event.accepted = true
        }

        MouseArea {
            anchors.fill: parent
            onClicked: function(mouse) { mouse.accepted = true }
        }

        Flickable {
            anchors.fill: parent
            anchors.margins: 12
            contentWidth: width
            contentHeight: content.implicitHeight
            boundsBehavior: Flickable.StopAtBounds
            flickableDirection: Flickable.VerticalFlick
            clip: true
            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

            Column {
                id: content
                width: parent.width
                spacing: 10

                Row {
                    width: parent.width
                    height: 44
                    spacing: 10

                    Rectangle {
                        width: 34; height: 34; radius: 17
                        anchors.verticalCenter: parent.verticalCenter
                        color: Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.13)
                        IconText {
                            anchors.centerIn: parent
                            text: IconMap.icon(panel.iconName())
                            color: network.needsAttention ? root.sealRaw
                                : network.connected ? root.seal : root.sumi
                            font.pixelSize: 21
                        }
                    }

                    Column {
                        width: parent.width - 94
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2
                        Text {
                            width: parent.width
                            text: panel.headerTitle()
                            color: root.ink
                            font.family: root.mono
                            font.pixelSize: 14
                            font.bold: true
                            elide: Text.ElideRight
                        }
                        Text {
                            width: parent.width
                            text: network.connected ? panel.phrases[panel.phraseIndex]
                                : network.connectivity.toUpperCase()
                            color: network.needsAttention ? root.sealRaw : root.sumi
                            font.family: root.mono
                            font.pixelSize: 9
                            font.bold: true
                            font.letterSpacing: 1.1
                            elide: Text.ElideRight
                        }
                    }

                    Rectangle {
                        width: 38; height: 20; radius: 10
                        anchors.verticalCenter: parent.verticalCenter
                        visible: network.wifiDevice !== null
                        color: network.wifiEnabled ? root.seal : root.pill
                        border.color: root.pillBorder
                        border.width: 1
                        opacity: network.toggling ? 0.55 : 1
                        Rectangle {
                            width: 14; height: 14; radius: 7; y: 3
                            x: network.wifiEnabled ? parent.width - width - 3 : 3
                            color: network.wifiEnabled ? root.bg : root.sumi
                            Behavior on x { NumberAnimation { duration: 120 } }
                        }
                        MouseArea {
                            anchors.fill: parent
                            enabled: !network.toggling
                            cursorShape: Qt.PointingHandCursor
                            onClicked: network.toggleNetwork()
                        }
                    }
                }

                Text {
                    width: parent.width
                    visible: network.lastError !== ""
                    text: network.lastError
                    color: root.sealRaw
                    font.family: root.mono
                    font.pixelSize: 9
                    wrapMode: Text.Wrap
                }

                Grid {
                    width: parent.width
                    columns: 4
                    columnSpacing: 10
                    rowSpacing: 5

                    MetricLabel { text: "Ping" }
                    MetricValue { text: panel.metric(network.pingMs, " ms", network.pingMs > 0 && network.pingMs < 10 ? 1 : 0) }
                    MetricLabel { text: "Packet Loss" }
                    MetricValue { text: network.packetLossPercent < 0 ? "Unavailable" : network.packetLossPercent + "%"; warning: network.packetLossPercent > 0 }
                    MetricLabel { text: "Receiving" }
                    MetricValue { text: network.formatRate(network.receiveRateBytes) }
                    MetricLabel { text: "Sending" }
                    MetricValue { text: network.formatRate(network.transmitRateBytes) }
                    MetricLabel { text: "Downloaded" }
                    MetricValue { text: network.formatBytes(network.receivedTotalBytes) }
                    MetricLabel { text: "Uploaded" }
                    MetricValue { text: network.formatBytes(network.transmittedTotalBytes) }
                    MetricLabel { text: "IP Address" }
                    MetricValue { text: network.ipAddress || "—" }
                    MetricLabel { text: "Gateway" }
                    MetricValue { text: network.gateway || "—" }
                }

                Rectangle { width: parent.width; height: 1; color: root.sep }

                Item {
                    width: parent.width
                    height: 27
                    Text {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: "SPEED TEST"
                        color: root.sumi
                        font.family: root.mono
                        font.pixelSize: 9
                        font.bold: true
                        font.letterSpacing: 1.3
                    }
                    Rectangle {
                        width: runLabel.implicitWidth + 16
                        height: 25
                        radius: 6
                        anchors.right: parent.right
                        color: runMouse.containsMouse && runMouse.enabled ? root.seal : root.pill
                        border.color: root.pillBorder
                        border.width: 1
                        Text {
                            id: runLabel
                            anchors.centerIn: parent
                            text: network.speedTestRunning ? "Running…"
                                : network.speedTestAvailable ? "Run" : "Unavailable"
                            color: runMouse.containsMouse && runMouse.enabled ? root.bg : root.ink
                            font.family: root.mono
                            font.pixelSize: 9
                        }
                        MouseArea {
                            id: runMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            enabled: network.speedTestAvailable && network.connected
                                && !network.speedTestRunning
                            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onClicked: network.runSpeedTest()
                        }
                    }
                }

                Row {
                    width: parent.width
                    visible: network.speedTestDownloadMbps >= 0
                        || network.speedTestUploadMbps >= 0 || network.speedTestError !== ""
                    spacing: 12
                    Text {
                        text: network.speedTestDownloadMbps >= 0
                            ? "↓ " + network.speedTestDownloadMbps.toFixed(1) + " Mbps" : "↓ —"
                        color: root.seal; font.family: root.mono; font.pixelSize: 10
                    }
                    Text {
                        text: network.speedTestUploadMbps >= 0
                            ? "↑ " + network.speedTestUploadMbps.toFixed(1) + " Mbps" : "↑ —"
                        color: root.indigo; font.family: root.mono; font.pixelSize: 10
                    }
                    Text {
                        visible: network.speedTestError !== ""
                        text: network.speedTestError
                        color: root.sealRaw; font.family: root.mono; font.pixelSize: 9
                        elide: Text.ElideRight
                    }
                }

                Text {
                    text: "DNS PROVIDER"
                    color: root.sumi
                    font.family: root.mono
                    font.pixelSize: 9
                    font.bold: true
                    font.letterSpacing: 1.3
                }

                Row {
                    width: parent.width
                    spacing: 5
                    Repeater {
                        model: panel.dnsProviders
                        delegate: Rectangle {
                            required property string modelData
                            required property int index
                            width: (content.width - 15) / 4
                            height: 27
                            radius: 6
                            color: network.dnsMode === modelData || (panel.focusSection === "dns" && panel.dnsIndex === index)
                                ? root.seal : root.pill
                            border.color: root.pillBorder
                            border.width: 1
                            opacity: network.dnsBusy ? 0.55 : 1
                            Text {
                                anchors.centerIn: parent
                                text: modelData
                                color: parent.color === root.seal ? root.bg : root.ink
                                font.family: root.mono
                                font.pixelSize: 8
                            }
                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                enabled: !network.dnsBusy
                                cursorShape: Qt.PointingHandCursor
                                onEntered: { panel.focusSection = "dns"; panel.dnsIndex = index }
                                onClicked: panel.activateDns(modelData)
                            }
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: customDnsOpen ? 66 : 0
                    visible: customDnsOpen
                    radius: 7
                    color: root.pill
                    border.color: network.validCustomDns(customDnsText) || customDnsText === ""
                        ? root.pillBorder : root.sealRaw
                    border.width: 1
                    Column {
                        anchors.fill: parent
                        anchors.margins: 7
                        spacing: 5
                        TextInput {
                            id: customDnsInput
                            width: parent.width
                            height: 22
                            text: panel.customDnsText
                            onTextChanged: panel.customDnsText = text
                            color: root.ink
                            selectionColor: root.seal
                            font.family: root.mono
                            font.pixelSize: 10
                            clip: true
                            Keys.onReturnPressed: panel.submitCustomDns()
                            Text {
                                visible: parent.text === ""
                                text: "1.1.1.1 2606:4700:4700::1111"
                                color: root.sumi
                                font: parent.font
                            }
                        }
                        Row {
                            spacing: 10
                            Text {
                                text: "Apply"
                                color: network.validCustomDns(customDnsText) ? root.seal : root.sumi
                                font.family: root.mono; font.pixelSize: 9
                                MouseArea {
                                    anchors.fill: parent
                                    enabled: network.validCustomDns(customDnsText)
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: panel.submitCustomDns()
                                }
                            }
                            Text {
                                text: "Cancel"; color: root.sumi
                                font.family: root.mono; font.pixelSize: 9
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        panel.customDnsOpen = false
                                        panel.customDnsText = ""
                                        card.forceActiveFocus()
                                    }
                                }
                            }
                        }
                    }
                }

                Item {
                    width: parent.width
                    height: 18
                    Text {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: "OTHER NETWORKS"
                        color: root.sumi
                        font.family: root.mono
                        font.pixelSize: 9
                        font.bold: true
                        font.letterSpacing: 1.3
                    }
                    Text {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: network.scanning ? "Scanning…" : network.nearbyNetworks.length + " found"
                        color: root.sumi
                        font.family: root.mono
                        font.pixelSize: 8
                    }
                }

                Text {
                    width: parent.width
                    visible: !network.wifiDevice || !network.wifiEnabled
                        || network.nearbyNetworks.length === 0
                    text: !network.wifiDevice ? "No Wi-Fi adapter"
                        : !network.wifiEnabled ? "Wi-Fi is disabled"
                        : network.scanning ? "Scanning nearby networks…" : "No other networks found"
                    color: root.sumi
                    font.family: root.mono
                    font.pixelSize: 10
                    horizontalAlignment: Text.AlignHCenter
                    topPadding: 8
                    bottomPadding: 8
                }

                ListView {
                    id: networkList
                    width: parent.width
                    height: Math.min(2, count) * 37
                        + (panel.passwordSsid !== "" ? 43 : 0)
                    model: network.nearbyNetworks
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    spacing: 0
                    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                    delegate: Rectangle {
                        id: networkRow
                        required property var modelData
                        required property int index
                        width: networkList.width
                        height: panel.passwordSsid === modelData.ssid ? 80 : 37
                        radius: 7
                        color: index === panel.selectedIndex || rowHover.hovered
                            ? root.pill : "transparent"
                        border.color: index === panel.selectedIndex
                            ? root.pillBorder : "transparent"
                        border.width: 1

                        HoverHandler {
                            id: rowHover
                            onHoveredChanged: if (hovered) {
                                panel.selectedIndex = networkRow.index
                                panel.focusSection = "wifi"
                            }
                        }

                        Row {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            height: 37
                            anchors.margins: 6
                            spacing: 7
                            IconText {
                                width: 20
                                anchors.verticalCenter: parent.verticalCenter
                                text: IconMap.icon(panel.wifiIcon(networkRow.modelData.signal))
                                color: root.seal
                                font.pixelSize: 15
                                horizontalAlignment: Text.AlignHCenter
                            }
                            Text {
                                width: parent.width - 70
                                anchors.verticalCenter: parent.verticalCenter
                                text: networkRow.modelData.ssid
                                color: root.ink
                                font.family: root.mono
                                font.pixelSize: 10
                                elide: Text.ElideRight
                            }
                            Text {
                                width: 16
                                anchors.verticalCenter: parent.verticalCenter
                                text: networkRow.modelData.secured ? "" : ""
                                color: root.sumi
                                font.family: root.mono
                                font.pixelSize: 10
                                horizontalAlignment: Text.AlignHCenter
                            }
                        }

                        MouseArea {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            height: 37
                            enabled: panel.passwordSsid === ""
                            cursorShape: Qt.PointingHandCursor
                            onClicked: panel.activateNetwork(networkRow.modelData)
                        }

                        Row {
                            visible: panel.passwordSsid === networkRow.modelData.ssid
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            anchors.margins: 7
                            height: 30
                            spacing: 6

                            Rectangle {
                                width: parent.width - 74
                                height: 27
                                radius: 6
                                color: root.bg
                                border.color: root.pillBorder
                                border.width: 1
                                TextInput {
                                    id: passwordInput
                                    anchors.fill: parent
                                    anchors.margins: 5
                                    text: panel.passwordText
                                    onTextChanged: panel.passwordText = text
                                    echoMode: panel.revealPassword ? TextInput.Normal : TextInput.Password
                                    color: root.ink
                                    selectionColor: root.seal
                                    font.family: root.mono
                                    font.pixelSize: 10
                                    clip: true
                                    Keys.onReturnPressed: panel.submitPassword()
                                }
                            }
                            Text {
                                width: 18
                                anchors.verticalCenter: parent.verticalCenter
                                text: panel.revealPassword ? "" : ""
                                color: root.sumi
                                font.family: root.mono
                                font.pixelSize: 10
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: panel.revealPassword = !panel.revealPassword
                                }
                            }
                            Text {
                                width: 38
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Join"
                                color: panel.passwordText !== "" ? root.seal : root.sumi
                                font.family: root.mono
                                font.pixelSize: 9
                                MouseArea {
                                    anchors.fill: parent
                                    enabled: panel.passwordText !== ""
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: panel.submitPassword()
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    component MetricLabel: Text {
        width: 72
        height: 16
        verticalAlignment: Text.AlignVCenter
        color: root.sumi
        font.family: root.mono
        font.pixelSize: 8
        elide: Text.ElideRight
    }

    component MetricValue: Text {
        property bool warning: false
        width: 85
        height: 16
        verticalAlignment: Text.AlignVCenter
        color: warning ? root.sealRaw : root.ink
        font.family: root.mono
        font.pixelSize: 9
        font.weight: Font.Medium
        elide: Text.ElideMiddle
    }
}
