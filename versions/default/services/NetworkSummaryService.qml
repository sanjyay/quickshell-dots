import QtQuick
import Quickshell.Io

QtObject {
    id: service

    property bool enabled: true
    property bool panelVisible: false
    property bool useNetworkManager: false
    property string mode: "none"
    property string ssid: ""
    property int signalStrength: 0
    property string iface: ""
    property real previousRx: -1
    property real previousTx: -1
    property real previousMs: 0
    property real downloadRate: 0
    property real uploadRate: 0
    property var downloadHistory: []
    property var uploadHistory: []
    readonly property int maxSamples: 30
    readonly property bool fastPoll: enabled || panelVisible || mode === "wifi"

    property Process backendProbe: Process {
        command: ["bash", "-c", "systemctl is-active --quiet NetworkManager && echo 1 || echo 0"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: service.useNetworkManager = this.text.trim() === "1"
        }
    }

    function updateSpeeds(rx, tx, now) {
        if (previousRx >= 0 && previousMs > 0) {
            var elapsed = (now - previousMs) / 1000
            if (elapsed > 0) {
                downloadRate = Math.max(0, (rx - previousRx) / elapsed)
                uploadRate = Math.max(0, (tx - previousTx) / elapsed)
                var downloads = downloadHistory.slice()
                downloads.push(downloadRate)
                if (downloads.length > maxSamples) downloads.shift()
                downloadHistory = downloads
                var uploads = uploadHistory.slice()
                uploads.push(uploadRate)
                if (uploads.length > maxSamples) uploads.shift()
                uploadHistory = uploads
            }
        }
        previousRx = rx
        previousTx = tx
        previousMs = now
    }

    function refresh() {
        networkReadProc.running = false
        networkReadProc.running = true
    }

    onFastPollChanged: if (fastPoll) refresh()

    property Process networkReadProc: Process {
        command: ["bash", "-c",
            "IFACE=$(ip route get 1.1.1.1 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i==\"dev\"){print $(i+1); exit}}'); " +
            "if [ -z \"$IFACE\" ]; then echo NONE; exit; fi; " +
            "RX=$(awk -v i=\"$IFACE:\" '$1==i{print $2}' /proc/net/dev 2>/dev/null); " +
            "TX=$(awk -v i=\"$IFACE:\" '$1==i{print $10}' /proc/net/dev 2>/dev/null); " +
            "if [ -d \"/sys/class/net/$IFACE/wireless\" ]; then " +
            "LINK=$(iw dev \"$IFACE\" link 2>/dev/null); " +
            "SSID=$(printf '%s\\n' \"$LINK\" | sed -n 's/^\\s*SSID: //p' | head -1); " +
            "SIG=$(printf '%s\\n' \"$LINK\" | awk '/signal:/ {print int($2); exit}'); " +
            "QUAL=$(awk -v s=\"$SIG\" 'BEGIN{q=int((s+110)*100/70);if(q<0)q=0;if(q>100)q=100;print q}'); " +
            "printf 'WIFI\\t%s\\t%s\\t%s\\t%s\\n' \"$SSID\" \"$QUAL\" \"$RX\" \"$TX\"; " +
            "else printf 'ETHERNET\\t%s\\t%s\\t%s\\n' \"$IFACE\" \"$RX\" \"$TX\"; fi"]
        stdout: StdioCollector {
            onStreamFinished: {
                var parts = this.text.trim().split("\t")
                var now = Date.now()
                if (parts[0] === "WIFI" && parts.length >= 5) {
                    service.mode = "wifi"
                    service.ssid = parts[1] || ""
                    service.signalStrength = parseInt(parts[2]) || 0
                    service.updateSpeeds(parseFloat(parts[3]) || 0, parseFloat(parts[4]) || 0, now)
                } else if (parts[0] === "ETHERNET" && parts.length >= 4) {
                    service.mode = "ethernet"
                    service.iface = parts[1] || ""
                    service.updateSpeeds(parseFloat(parts[2]) || 0, parseFloat(parts[3]) || 0, now)
                } else {
                    service.mode = "none"
                    service.previousRx = -1
                    service.previousTx = -1
                }
            }
        }
    }

    property Timer networkTimer: Timer {
        interval: service.fastPoll ? 2000 : 60000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: service.refresh()
    }
}
