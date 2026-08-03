import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../modules"

PanelWindow {
    id: panel
    required property var root

    readonly property var tailscale: root.tailscale
    property real reveal: root.tailscaleVisible ? 1 : 0
    property int selectedPeerIndex: tailscale.peers.length > 0 ? 0 : -1
    property string copiedValue: ""

    screen: root.activePopupScreen
    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-astra-tailscale"
    WlrLayershell.keyboardFocus: root.tailscaleVisible
        ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    visible: reveal > 0.001

    Behavior on reveal {
        NumberAnimation {
            duration: root.tailscaleVisible ? 160 : 120
            easing.type: root.tailscaleVisible ? Easing.OutCubic : Easing.InCubic
        }
    }

    function closePanel() {
        root.tailscaleVisible = false
    }

    function selectedPeer() {
        if (selectedPeerIndex < 0 || selectedPeerIndex >= tailscale.peers.length)
            return null
        return tailscale.peers[selectedPeerIndex]
    }

    function peerName(peer) {
        return peer ? tailscale.displayHostName(peer.HostName, peer.DNSName) : ""
    }

    function peerDns(peer) {
        return peer ? tailscale.cleanDnsName(peer.DNSName) : ""
    }

    function peerIp(peer) {
        if (!peer) return ""
        var ips = tailscale.filterIPv4(peer.TailscaleIPs || [])
        return ips.length > 0 ? ips[0] : ""
    }

    function copyPeer(kind, peer) {
        if (!peer) return
        var value = ""
        if (kind === "ip") {
            value = peerIp(peer)
            tailscale.copyPeerIp(peer)
        } else if (kind === "dns") {
            value = peerDns(peer)
            tailscale.copyPeerDnsName(peer)
        } else {
            value = peerName(peer)
            tailscale.copyPeerName(peer)
        }
        if (value !== "") {
            copiedValue = value
            copiedTimer.restart()
        }
    }

    function copySelfIp() {
        if (tailscale.selfIp === "") return
        tailscale.copyToClipboard(tailscale.selfIp, "This device IP")
        copiedValue = tailscale.selfIp
        copiedTimer.restart()
    }

    function sendTo(peer) {
        if (!tailscale.canSendFiles(peer)) return
        tailscale.sendFile(peer)
        closePanel()
    }

    function moveSelection(delta) {
        if (tailscale.peers.length === 0) {
            selectedPeerIndex = -1
            return
        }
        selectedPeerIndex = Math.max(0, Math.min(
            tailscale.peers.length - 1,
            (selectedPeerIndex < 0 ? 0 : selectedPeerIndex) + delta))
    }

    onVisibleChanged: {
        if (!visible) return
        selectedPeerIndex = tailscale.peers.length > 0 ? 0 : -1
        tailscale.refresh(true)
        Qt.callLater(function() { card.forceActiveFocus() })
    }

    Connections {
        target: tailscale
        function onPeersChanged() {
            if (tailscale.peers.length === 0) panel.selectedPeerIndex = -1
            else if (panel.selectedPeerIndex < 0
                     || panel.selectedPeerIndex >= tailscale.peers.length)
                panel.selectedPeerIndex = 0
        }
    }

    Timer {
        id: copiedTimer
        interval: 1400
        onTriggered: panel.copiedValue = ""
    }

    IpcHandler {
        target: "quickshell-astra-tailscale"

        function open(): string {
            root.activateFocusedPopupScreen()
            root.tailscaleVisible = true
            return "opened"
        }

        function close(): string {
            panel.closePanel()
            return "closed"
        }

        function toggle(): string {
            if (!root.tailscaleVisible) root.activateFocusedPopupScreen()
            root.tailscaleVisible = !root.tailscaleVisible
            return root.tailscaleVisible ? "opened" : "closed"
        }

        function refresh(): string {
            tailscale.refresh(true)
            return "refreshing"
        }

        function state(): string {
            return JSON.stringify({
                visible: root.tailscaleVisible,
                installed: tailscale.installed,
                active: tailscale.active,
                status: tailscale.statusText,
                peerCount: tailscale.peers.length,
                taildropTargetCount: tailscale.peers.filter(function(peer) {
                    return tailscale.canSendFiles(peer)
                }).length
            })
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: panel.closePanel()
    }

    Rectangle {
        id: card
        width: Math.min(390, panel.width - 12)
        height: Math.min(content.implicitHeight + 24, panel.height - 96)
        x: Math.round(Math.max(6, Math.min(
            root.tailscaleBarX - width / 2, panel.width - width - 6)))
        y: root.barPosition === "bottom"
            ? panel.height - 35 - 8 - height : 35 + 8
        radius: panel.reveal > 0.001 ? root.pillRadius : 0
        color: root.bg
        border.color: root.pillBorder
        border.width: root.pillBorderW
        opacity: panel.reveal
        focus: root.tailscaleVisible
        clip: true

        PillShadow { theme: root }

        Keys.onPressed: function(event) {
            var peer = panel.selectedPeer()
            if (event.key === Qt.Key_Escape) panel.closePanel()
            else if (event.key === Qt.Key_Down || event.key === Qt.Key_J)
                panel.moveSelection(1)
            else if (event.key === Qt.Key_Up || event.key === Qt.Key_K)
                panel.moveSelection(-1)
            else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter
                     || event.key === Qt.Key_Space)
                panel.sendTo(peer)
            else if (event.key === Qt.Key_C) panel.copyPeer("ip", peer)
            else if (event.key === Qt.Key_N) panel.copyPeer("name", peer)
            else if (event.key === Qt.Key_D) panel.copyPeer("dns", peer)
            else if (event.key === Qt.Key_S) panel.sendTo(peer)
            else if (event.key === Qt.Key_T) tailscale.toggleTailscale()
            else if (event.key === Qt.Key_R) tailscale.refresh(true)
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
                    height: 42
                    spacing: 10

                    TailscaleIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        iconSize: 25
                        color: tailscale.active ? root.seal : root.sumi
                        crossed: !tailscale.active && !tailscale.needsLogin
                        warning: tailscale.needsLogin
                    }

                    Column {
                        width: parent.width - 100
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2

                        Text {
                            width: parent.width
                            text: tailscale.selfName || "Tailscale"
                            color: root.ink
                            font.family: root.mono
                            font.pixelSize: 14
                            font.bold: true
                            elide: Text.ElideRight
                        }
                        Text {
                            width: parent.width
                            text: tailscale.statusText
                            color: tailscale.needsLogin ? root.urgent : root.sumi
                            font.family: root.mono
                            font.pixelSize: 10
                            elide: Text.ElideRight
                        }
                    }

                    Rectangle {
                        width: 38
                        height: 20
                        radius: 10
                        anchors.verticalCenter: parent.verticalCenter
                        color: tailscale.active ? root.seal : root.pill
                        border.color: root.pillBorder
                        border.width: 1

                        Rectangle {
                            width: 14
                            height: 14
                            radius: 7
                            y: 3
                            x: tailscale.active ? parent.width - width - 3 : 3
                            color: tailscale.active ? root.bg : root.sumi
                            Behavior on x { NumberAnimation { duration: 120 } }
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: tailscale.toggleTailscale()
                        }
                    }
                }

                Text {
                    width: parent.width
                    visible: tailscale.lastError !== "" || tailscale.actionStatus !== ""
                    text: tailscale.actionStatus !== ""
                        ? tailscale.actionStatus : tailscale.lastError
                    color: tailscale.lastError !== "" ? root.urgent : root.sumi
                    font.family: root.mono
                    font.pixelSize: 10
                    wrapMode: Text.Wrap
                }

                Row {
                    width: parent.width
                    height: 27
                    visible: tailscale.active
                    spacing: 6

                    Text {
                        width: parent.width - selfCopyButton.width - parent.spacing
                        anchors.verticalCenter: parent.verticalCenter
                        text: [tailscale.selfIp, tailscale.selfDnsName]
                            .filter(function(value) { return value !== "" }).join("  ·  ")
                        color: root.sumi
                        font.family: root.mono
                        font.pixelSize: 10
                        elide: Text.ElideMiddle
                    }

                    Rectangle {
                        id: selfCopyButton
                        width: 27
                        height: 27
                        radius: 6
                        color: selfCopyMouse.containsMouse ? root.seal : root.pill

                        Text {
                            anchors.centerIn: parent
                            text: panel.copiedValue === tailscale.selfIp ? "✓" : "󰆏"
                            color: selfCopyMouse.containsMouse ? root.bg : root.ink
                            font.family: root.mono
                            font.pixelSize: 11
                        }
                        MouseArea {
                            id: selfCopyMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            enabled: tailscale.selfIp !== ""
                            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onClicked: panel.copySelfIp()
                        }
                    }
                }

                Text {
                    visible: tailscale.accounts.length > 1
                    text: "CONNECTIONS"
                    color: root.sumi
                    font.family: root.mono
                    font.pixelSize: 10
                    font.letterSpacing: 1.5
                }

                Repeater {
                    model: tailscale.accounts.length > 1 ? tailscale.accounts : []
                    delegate: Rectangle {
                        required property var modelData
                        width: content.width
                        height: 30
                        radius: 6
                        color: modelData.selected ? root.pill : "transparent"

                        Text {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.margins: 8
                            text: tailscale.accountLabel(modelData)
                            color: root.ink
                            font.family: root.mono
                            font.pixelSize: 11
                            elide: Text.ElideRight
                        }
                        MouseArea {
                            anchors.fill: parent
                            enabled: !modelData.selected && !tailscale.busy
                            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onClicked: tailscale.switchAccount(modelData.id)
                        }
                    }
                }

                Text {
                    visible: tailscale.exitNodes.length > 0
                    text: "EXIT NODES"
                    color: root.sumi
                    font.family: root.mono
                    font.pixelSize: 10
                    font.letterSpacing: 1.5
                }

                Flow {
                    width: parent.width
                    spacing: 5
                    visible: tailscale.exitNodes.length > 0

                    Repeater {
                        model: tailscale.exitNodes
                        delegate: Rectangle {
                            required property var modelData
                            width: exitLabel.implicitWidth + 14
                            height: 25
                            radius: 6
                            color: modelData.ExitNode ? root.seal : root.pill
                            border.color: root.pillBorder
                            border.width: 1

                            Text {
                                id: exitLabel
                                anchors.centerIn: parent
                                text: modelData.ExitNode
                                    ? "Disconnect " + panel.peerName(modelData)
                                    : panel.peerName(modelData)
                                color: modelData.ExitNode ? root.bg : root.ink
                                font.family: root.mono
                                font.pixelSize: 9
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: tailscale.setExitNode(modelData)
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
                        text: "MACHINES"
                        color: root.sumi
                        font.family: root.mono
                        font.pixelSize: 10
                        font.letterSpacing: 1.5
                    }

                    Text {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: tailscale.peers.length
                            + (tailscale.peers.length === 1 ? " device online" : " devices online")
                        color: root.sumi
                        font.family: root.mono
                        font.pixelSize: 10
                    }
                }

                Text {
                    width: parent.width
                    visible: !tailscale.installed || !tailscale.active
                             || tailscale.peers.length === 0
                    text: !tailscale.installed
                        ? "Tailscale is not installed"
                        : tailscale.needsLogin
                            ? "Sign in to see your tailnet"
                            : !tailscale.active
                                ? "Connect Tailscale to see machines"
                                : "No online machines"
                    color: root.sumi
                    font.family: root.mono
                    font.pixelSize: 11
                    horizontalAlignment: Text.AlignHCenter
                    topPadding: 12
                    bottomPadding: 12
                }

                Repeater {
                    model: tailscale.peers
                    delegate: Rectangle {
                        id: peerRow
                        required property var modelData
                        required property int index
                        width: content.width
                        height: 52
                        radius: 7
                        color: index === panel.selectedPeerIndex || hover.hovered
                            ? root.pill : "transparent"
                        border.color: index === panel.selectedPeerIndex
                            ? root.pillBorder : "transparent"
                        border.width: 1

                        HoverHandler {
                            id: hover
                            onHoveredChanged: if (hovered)
                                panel.selectedPeerIndex = peerRow.index
                        }

                        Row {
                            anchors.fill: parent
                            anchors.margins: 7
                            spacing: 8

                            Text {
                                width: 20
                                anchors.verticalCenter: parent.verticalCenter
                                text: tailscale.osIcon(peerRow.modelData.OS)
                                color: root.seal
                                font.family: root.mono
                                font.pixelSize: 15
                                horizontalAlignment: Text.AlignHCenter
                            }

                            Column {
                                width: parent.width - 128
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 2

                                Text {
                                    width: parent.width
                                    text: panel.peerName(peerRow.modelData)
                                    color: root.ink
                                    font.family: root.mono
                                    font.pixelSize: 11
                                    font.bold: true
                                    elide: Text.ElideRight
                                }
                                Text {
                                    width: parent.width
                                    text: [panel.peerIp(peerRow.modelData),
                                           panel.peerDns(peerRow.modelData)]
                                        .filter(function(value) { return value !== "" })
                                        .join("  ·  ")
                                    color: root.sumi
                                    font.family: root.mono
                                    font.pixelSize: 9
                                    elide: Text.ElideMiddle
                                }
                            }

                            Row {
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 4

                                Rectangle {
                                    width: 27; height: 27; radius: 6
                                    color: copyIpMouse.containsMouse ? root.seal : root.pill
                                    Text {
                                        anchors.centerIn: parent
                                        text: panel.copiedValue === panel.peerIp(peerRow.modelData)
                                            ? "✓" : "󰆏"
                                        color: copyIpMouse.containsMouse ? root.bg : root.ink
                                        font.family: root.mono
                                        font.pixelSize: 11
                                    }
                                    MouseArea {
                                        id: copyIpMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: panel.copyPeer("ip", peerRow.modelData)
                                    }
                                }

                                Rectangle {
                                    width: 27; height: 27; radius: 6
                                    visible: tailscale.canSendFiles(peerRow.modelData)
                                    color: sendMouse.containsMouse ? root.seal : root.pill
                                    Text {
                                        anchors.centerIn: parent
                                        text: "󰒊"
                                        color: sendMouse.containsMouse ? root.bg : root.ink
                                        font.family: root.mono
                                        font.pixelSize: 14
                                    }
                                    MouseArea {
                                        id: sendMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        enabled: !tailscale.busy
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: panel.sendTo(peerRow.modelData)
                                    }
                                }
                            }
                        }
                    }
                }

                Text {
                    width: parent.width
                    visible: tailscale.active && !tailscale.fileSharing
                    text: "Taildrop is unavailable for this tailnet"
                    color: root.sumi
                    font.family: root.mono
                    font.pixelSize: 9
                    horizontalAlignment: Text.AlignHCenter
                }

            }
        }
    }
}
