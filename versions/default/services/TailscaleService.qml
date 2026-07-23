import QtQuick
import Quickshell.Io

QtObject {
    id: service

    property bool enabled: false
    property bool available: false
    property string status: "unknown"
    property string hostName: ""
    property string address: ""
    property string tailnet: ""
    property string backendState: "Unknown"
    property int peerCount: 0

    function refresh() {
        statusProc.running = false
        statusProc.running = true
    }

    function clearIdentity() {
        hostName = ""
        address = ""
        tailnet = ""
    }

    property Process statusProc: Process {
        command: ["bash", "-lc",
            "if ! command -v tailscale >/dev/null 2>&1; then printf '__UNAVAILABLE__\\n'; "
            + "else tailscale status --json 2>/dev/null || printf '__ERROR__\\n'; fi"]
        stdout: StdioCollector { id: statusOut }
        onExited: {
            var output = statusOut.text.trim()
            if (output === "__UNAVAILABLE__") {
                service.available = false
                service.status = "unavailable"
                service.clearIdentity()
                service.backendState = "Unavailable"
                service.peerCount = 0
                return
            }
            service.available = true
            if (output === "__ERROR__" || output === "") {
                service.status = "disconnected"
                service.backendState = "Stopped"
                service.peerCount = 0
                return
            }
            try {
                var state = JSON.parse(output)
                var backend = String(state.BackendState || "Unknown")
                service.backendState = backend
                var self = state.Self || ({})
                service.status = backend === "Running" && self.Online
                    ? "connected"
                    : (backend === "NeedsLogin" ? "login-required" : "disconnected")
                service.hostName = String(self.HostName || self.DNSName || "").replace(/\.$/, "")
                var addresses = state.TailscaleIPs || self.TailscaleIPs || []
                service.address = addresses.length > 0 ? String(addresses[0]) : ""
                service.tailnet = state.CurrentTailnet ? String(state.CurrentTailnet.Name || "") : ""
                var peers = state.Peer || ({})
                var onlinePeers = 0
                for (var peerId in peers) if (peers[peerId] && peers[peerId].Online) onlinePeers++
                service.peerCount = onlinePeers
            } catch (error) {
                service.status = "disconnected"
                service.backendState = "Unknown"
                service.peerCount = 0
            }
        }
    }

    property Timer pollTimer: Timer {
        interval: 10000
        running: service.enabled
        repeat: true
        triggeredOnStart: true
        onTriggered: service.refresh()
    }
}
