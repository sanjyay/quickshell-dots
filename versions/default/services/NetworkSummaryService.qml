import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Networking
import "NetworkModel.js" as Model

Item {
    id: service

    property bool enabled: true
    property bool panelVisible: false
    readonly property bool installed: Networking.backend === NetworkBackendType.NetworkManager
    readonly property bool wifiEnabled: installed && Networking.wifiEnabled
    readonly property var devices: Networking.devices ? Networking.devices.values : []
    readonly property var wifiDevice: findDevice(DeviceType.Wifi)
    readonly property var wiredDevice: findDevice(DeviceType.Wired)
    readonly property var wifiObjects: wifiDevice && wifiDevice.networks
        ? wifiDevice.networks.values : []
    readonly property var connectedWifi: findConnectedWifi()
    readonly property bool active: installed
    readonly property bool connected: connectionType !== "none"
    readonly property string connectionType: info.type || nativeConnectionType
    readonly property string connectionName: connectionType === "wifi"
        ? (info.ssid || (connectedWifi ? connectedWifi.name : "Wi-Fi"))
        : (connectionType === "ethernet" ? "Ethernet" : "")
    readonly property string connectedSsid: connectionType === "wifi" ? connectionName : ""
    readonly property string interfaceName: info.iface || ""
    readonly property string ipAddress: info.ip || ""
    readonly property string gateway: info.gateway || ""
    readonly property int connectionSpeedMbps: parseInt(info.speed || "0", 10) || 0
    readonly property real wifiFrequencyMHz: parseFloat(info.freq || "0") || 0
    readonly property string connectivity: connectivityName(Networking.connectivity)
    readonly property bool needsAttention: connectivity === "limited"
        || connectivity === "portal" || connectivity === "none"
    readonly property real receiveRateBytes: downloadRate
    readonly property real transmitRateBytes: uploadRate
    readonly property real receivedTotalBytes: parseFloat(info.rx_bytes || "0") || 0
    readonly property real transmittedTotalBytes: parseFloat(info.tx_bytes || "0") || 0
    readonly property bool busy: toggling || actionKind !== "" || dnsBusy
        || speedTestRunning || scanning
    readonly property bool refreshing: detailsProcess.running
    readonly property bool speedTestAvailable: speedTestProbe.available

    property var info: ({})
    property var nearbyNetworks: []
    property string dnsMode: "DHCP"
    property string selectedDnsProvider: dnsMode
    property var dnsServers: []
    property real pingMs: -1
    property int packetLossPercent: -1
    property var pingSamples: []
    property real previousRx: 0
    property real previousTx: 0
    property real previousMs: 0
    property string previousIface: ""
    property real downloadRate: 0
    property real uploadRate: 0
    property bool scanning: false
    property bool toggling: false
    property bool dnsBusy: false
    property string actionKind: ""
    property string actionSsid: ""
    property string lastError: ""
    property string lastErrorCode: ""
    property string lastRefreshAt: ""
    property string lastSuccessfulRefreshAt: ""
    property bool speedTestRunning: false
    property string speedTestPhase: ""
    property real speedTestDownloadMbps: -1
    property real speedTestUploadMbps: -1
    property real speedTestPingMs: -1
    property string speedTestError: ""
    property string speedOutput: ""
    property string speedError: ""
    property string dnsError: ""
    property bool speedExpectedStop: false
    property string customDnsValue: ""
    property string pendingDnsMode: ""
    property string scanOutput: ""
    property string scanError: ""
    property var fallbackWifiRows: []
    property string connectError: ""
    property string pendingPassword: ""
    property var knownSsids: []

    readonly property string nativeConnectionType: {
        if (wiredDevice && wiredDevice.connected) return "ethernet"
        if (connectedWifi) return "wifi"
        return "none"
    }

    function findDevice(type) {
        var fallback = null
        for (var i = 0; i < devices.length; i++) {
            var device = devices[i]
            if (!device || device.type !== type) continue
            if (device.connected) return device
            if (!fallback) fallback = device
        }
        return fallback
    }

    function findConnectedWifi() {
        for (var i = 0; i < wifiObjects.length; i++)
            if (wifiObjects[i] && wifiObjects[i].connected) return wifiObjects[i]
        return null
    }

    function connectivityName(value) {
        if (!installed) return "unavailable"
        if (value === NetworkConnectivity.Full) return "full"
        if (value === NetworkConnectivity.Limited) return "limited"
        if (value === NetworkConnectivity.Portal) return "portal"
        if (value === NetworkConnectivity.None) return "none"
        return connected ? "unknown" : "none"
    }

    function parseDetails(raw) {
        var next = Model.parseKeyValue(raw)
        if (!next.iface) {
            lastError = connected ? "Network details unavailable" : ""
            lastErrorCode = connected ? "details-unavailable" : ""
            return
        }

        var interfaceChanged = previousIface !== "" && previousIface !== next.iface
        var throughput = Model.throughputState({
            iface: previousIface, rx: previousRx, tx: previousTx, time: previousMs
        }, next, Date.now())
        previousIface = throughput.iface
        previousRx = throughput.rx
        previousTx = throughput.tx
        previousMs = throughput.time
        downloadRate = throughput.downloadRate
        uploadRate = throughput.uploadRate
        info = next
        if (interfaceChanged) pingSamples = []
        var ping = Model.pingState(pingSamples,
            next.internet_ping_ms === undefined ? "" : next.internet_ping_ms, 8)
        pingSamples = ping.samples
        pingMs = ping.latency
        packetLossPercent = ping.packetLoss
        lastError = ""
        lastErrorCode = ""
        lastSuccessfulRefreshAt = new Date().toISOString()
    }

    function parseMetric(value) {
        var number = parseFloat(value)
        return isFinite(number) && number >= 0 ? number : -1
    }

    function refresh(scanWifi) {
        lastRefreshAt = new Date().toISOString()
        if (!detailsProcess.running) detailsProcess.running = true
        if (!dnsProcess.running) dnsProcess.running = true
        if (!savedProfilesProcess.running) savedProfilesProcess.running = true
        if (scanWifi === true) scan()
        syncNetworks()
        if (Networking.canCheckConnectivity) Networking.checkConnectivity()
    }

    function scan() {
        if (!wifiDevice || scanning || scanProcess.running) return
        scanning = true
        wifiDevice.scannerEnabled = false
        scanOutput = ""
        scanError = ""
        scanProcess.running = true
        scanWatchdog.restart()
    }

    function sanitizeSsid(value) {
        return Model.sanitizeSsid(value)
    }

    function mergeFallbackScan(rows) {
        var now = Date.now()
        var byName = {}
        for (var i = 0; i < fallbackWifiRows.length; i++) {
            var old = fallbackWifiRows[i]
            if (old && old.name && now - Number(old.lastSeenAt || 0) < 45000)
                byName[old.name] = old
        }
        for (var j = 0; j < rows.length; j++) {
            var fresh = rows[j]
            if (!fresh || !fresh.name) continue
            fresh.lastSeenAt = now
            var previous = byName[fresh.name]
            if (previous && Number(previous.signalStrength || 0) > Number(fresh.signalStrength || 0))
                fresh.signalStrength = previous.signalStrength
            byName[fresh.name] = fresh
        }
        var merged = []
        for (var name in byName) merged.push(byName[name])
        return merged
    }

    function syncNetworks(fallbackRows) {
        if (fallbackRows) fallbackWifiRows = mergeFallbackScan(fallbackRows)
        var source = []
        var nativeNames = []
        for (var i = 0; i < wifiObjects.length; i++) {
            source.push(wifiObjects[i])
            nativeNames.push(sanitizeSsid(wifiObjects[i].name))
        }
        for (var j = 0; j < fallbackWifiRows.length; j++) {
            fallbackWifiRows[j].known = knownSsids.indexOf(fallbackWifiRows[j].name) >= 0
            // Never let an nmcli scan row replace the native object that owns
            // connect()/connectWithPsk(), even if its signal sample is newer.
            if (nativeNames.indexOf(sanitizeSsid(fallbackWifiRows[j].name)) < 0)
                source.push(fallbackWifiRows[j])
        }
        nearbyNetworks = Model.normalizeNetworks(source, connectedSsid,
            WifiSecurityType.Open, [WifiSecurityType.Wpa2Eap, WifiSecurityType.WpaEap])
        scanning = false
    }

    function toggleNetwork() {
        if (!installed || toggling || !wifiDevice) return
        toggling = true
        Networking.wifiEnabled = !Networking.wifiEnabled
        toggleDone.restart()
    }

    function connectNetwork(entry, password) {
        if (!entry || actionKind !== "") return
        actionKind = "connect"
        actionSsid = entry.ssid
        lastError = ""
        var nativeNetwork = entry.network
            && typeof entry.network.connect === "function"
            && typeof entry.network.connectWithPsk === "function"
        if (nativeNetwork) {
            if (entry.known || !entry.secured) entry.network.connect()
            else entry.network.connectWithPsk(String(password || ""))
        } else {
            pendingPassword = String(password || "")
            connectError = ""
            if (entry.known)
                connectProcess.command = ["nmcli", "--wait", "15", "connection", "up", "id", entry.ssid]
            else {
                connectProcess.command = ["nmcli", "--ask", "--wait", "15",
                    "device", "wifi", "connect", entry.ssid]
            }
            connectProcess.running = true
        }
        actionTimeout.restart()
    }

    function setDns(provider) {
        if (dnsBusy || ["DHCP", "Cloudflare", "Google"].indexOf(provider) < 0) return
        dnsBusy = true
        lastError = ""
        pendingDnsMode = provider
        dnsAction.command = ["omarchy-dns", provider]
        dnsAction.running = true
        dnsActionWatchdog.restart()
    }

    function validDnsAddress(value) {
        return Model.validDnsAddress(value)
    }

    function validCustomDns(value) {
        return Model.validCustomDns(value)
    }

    function runCustomDns(value) {
        Quickshell.execDetached([
            "omarchy-launch-floating-terminal-with-presentation",
            "omarchy-dns", "Custom"
        ])
        return true
    }

    function runSpeedTest() {
        if (!speedTestAvailable || speedTestRunning || !connected) return
        speedTestRunning = true
        speedTestError = ""
        speedTestDownloadMbps = -1
        speedTestUploadMbps = -1
        startSpeedPhase("down")
    }

    function startSpeedPhase(phase) {
        speedTestPhase = phase
        speedOutput = ""
        speedError = ""
        speedExpectedStop = false
        speedProcess.command = ["omarchy-network-speedtest", phase]
        speedProcess.running = true
        speedWatchdog.restart()
    }

    function finishSpeedPhase() {
        var lines = speedOutput.trim().split(/\s+/)
        var value = parseFloat(lines[lines.length - 1])
        if (!isFinite(value)) {
            speedTestError = speedError || "Speed test returned no measurement"
            speedTestRunning = false
            speedTestPhase = ""
        } else if (speedTestPhase === "down") {
            speedTestDownloadMbps = value
            startSpeedPhase("up")
        } else {
            speedTestUploadMbps = value
            speedTestRunning = false
            speedTestPhase = ""
        }
    }

    function formatBytes(value) {
        return Model.formatBytes(value)
    }

    function formatRate(value) { return formatBytes(value) + "/s" }

    onWifiObjectsChanged: syncNetworks()
    onConnectedWifiChanged: syncNetworks()
    onPanelVisibleChanged: {
        if (wifiDevice) wifiDevice.scannerEnabled = panelVisible
        if (panelVisible) refresh(true)
    }

    Process {
        id: detailsProcess
        command: ["omarchy-network-status", "--verbose"]
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: service.parseDetails(text)
        }
        onExited: function(code) {
            if (code !== 0) {
                service.lastError = "Network status command failed"
                service.lastErrorCode = "status-command-failed"
            }
        }
    }

    Process {
        id: scanProcess
        command: ["nmcli", "--terse", "--escape", "yes",
            "--fields", "SSID,SIGNAL,SECURITY", "device", "wifi", "list", "--rescan", "yes"]
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: service.scanOutput = String(text || "")
        }
        stderr: StdioCollector {
            waitForEnd: true
            onStreamFinished: service.scanError = String(text || "").trim()
        }
        onExited: function(code) {
            scanWatchdog.stop()
            service.scanning = false
            if (code === 0)
                service.syncNetworks(Model.parseNmcliWifi(service.scanOutput, service.connectedSsid))
            else {
                service.lastError = "Wi-Fi scan failed"
                service.lastErrorCode = "wifi-scan-failed"
            }
        }
    }

    Process {
        id: connectProcess
        stdinEnabled: true
        onStarted: {
            if (service.pendingPassword !== "") write(service.pendingPassword + "\n")
            service.pendingPassword = ""
        }
        stderr: StdioCollector {
            waitForEnd: true
            onStreamFinished: service.connectError = String(text || "").trim()
        }
        onExited: function(code) {
            actionTimeout.stop()
            if (code !== 0) {
                service.lastError = "Failed to connect to " + service.actionSsid
                service.lastErrorCode = "wifi-connect-failed"
            }
            service.actionKind = ""
            service.actionSsid = ""
            service.refresh(true)
        }
    }

    function updateDns(raw) {
        var mode = String(raw || "").trim()
        if (["DHCP", "Cloudflare", "Google", "Custom"].indexOf(mode) >= 0)
            dnsMode = mode
    }

    Process {
        id: dnsProcess
        command: ["omarchy-dns"]
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: service.updateDns(text)
        }
    }

    Process {
        id: dnsAction
        stderr: StdioCollector {
            waitForEnd: true
            onStreamFinished: service.dnsError = String(text || "").trim()
        }
        onExited: function(code) {
            dnsActionWatchdog.stop()
            service.dnsBusy = false
            service.customDnsValue = ""
            if (code !== 0) {
                service.lastError = service.dnsError !== ""
                    ? "DNS update was not authorized" : "DNS update failed"
                service.lastErrorCode = "dns-update-failed"
                service.pendingDnsMode = ""
                return
            }
            service.dnsMode = service.pendingDnsMode
            service.pendingDnsMode = ""
            dnsProcess.running = true
        }
    }

    Timer {
        id: dnsActionWatchdog
        interval: 60000
        repeat: false
        onTriggered: {
            if (dnsAction.running) dnsAction.running = false
            service.dnsBusy = false
            service.pendingDnsMode = ""
            service.lastError = "DNS update timed out"
            service.lastErrorCode = "dns-update-timeout"
        }
    }

    Process {
        id: savedProfilesProcess
        command: ["nmcli", "--terse", "--escape", "yes",
            "--fields", "NAME,TYPE", "connection", "show"]
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                var names = []
                var lines = String(text || "").split("\n")
                for (var i = 0; i < lines.length; i++) {
                    var fields = Model.splitNmcliLine(lines[i])
                    if (fields.length >= 2 && fields[1] === "802-11-wireless")
                        names.push(fields[0])
                }
                service.knownSsids = names
                service.syncNetworks()
            }
        }
    }

    Process {
        id: speedTestProbe
        property bool available: false
        command: ["which", "omarchy-network-speedtest"]
        running: true
        onExited: function(code) { available = code === 0 }
    }

    Process {
        id: speedProcess
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: service.speedOutput = String(text || "").trim()
        }
        stderr: StdioCollector {
            waitForEnd: true
            onStreamFinished: service.speedError = String(text || "").trim()
        }
        onExited: function(code) {
            speedWatchdog.stop()
            if (code !== 0 && !service.speedExpectedStop) {
                service.speedTestError = service.speedError || "Speed test failed"
                service.speedTestRunning = false
                service.speedTestPhase = ""
                service.speedExpectedStop = false
                return
            }
            service.speedExpectedStop = false
            service.finishSpeedPhase()
        }
    }

    Timer {
        interval: service.panelVisible ? 3000 : 5000
        running: service.enabled
        repeat: true
        triggeredOnStart: true
        onTriggered: service.refresh(false)
    }
    Timer {
        interval: 8000
        running: service.enabled && service.panelVisible
        repeat: true
        onTriggered: service.scan()
    }
    Timer {
        id: scanWatchdog
        interval: 8000
        onTriggered: {
            scanProcess.running = false
            service.scanning = false
            service.lastError = "Wi-Fi scan timed out"
            service.lastErrorCode = "wifi-scan-timeout"
        }
    }
    Timer {
        id: toggleDone
        interval: 800
        onTriggered: {
            service.toggling = false
            service.refresh(true)
        }
    }
    Timer {
        id: actionTimeout
        interval: 15000
        onTriggered: {
            service.lastError = "Timed out connecting to " + service.actionSsid
            service.lastErrorCode = "wifi-connect-timeout"
            service.actionKind = ""
            service.actionSsid = ""
        }
    }
    Timer {
        id: speedWatchdog
        interval: 5000
        onTriggered: {
            service.speedExpectedStop = true
            speedProcess.running = false
        }
    }

    Connections {
        target: service.connectedWifi
        function onConnectedChanged() {
            if (service.actionKind === "connect" && service.connectedWifi
                    && service.connectedWifi.name === service.actionSsid) {
                actionTimeout.stop()
                service.actionKind = ""
                service.actionSsid = ""
                service.refresh(true)
            }
        }
    }
}
