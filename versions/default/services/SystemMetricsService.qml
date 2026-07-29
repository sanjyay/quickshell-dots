import QtQuick
import Quickshell.Io

QtObject {
    id: service

    property bool enabled: false
    property bool panelVisible: false
    property int cpuPercent: 0
    property int cpuTemperature: 0
    property real cpuClockGHz: 0
    property int cpuCores: 0
    property int cpuThreads: 0
    property var cpuHistory: []
    property int ramPercent: 0
    property real ramUsedGiB: 0
    property real ramTotalGiB: 0

    property string gpuStatus: "never-collected"
    property string gpuProvider: ""
    property string gpuDevice: ""
    property string gpuName: ""
    property var gpuTemperatureC: null
    property var gpuUsagePercent: null
    property var gpuVramUsedMiB: null
    property var gpuVramTotalMiB: null
    property var gpuClockMHz: null
    property var gpuPowerWatts: null
    property string gpuCollectedAt: ""
    property string gpuErrorCode: ""
    property string gpuParseStatus: "never-collected"
    property int gpuLastExitCode: -1
    property int gpuStdoutBytes: 0
    property var gpuHistory: []
    readonly property string gpuCollectorPath: Qt.resolvedUrl("../modules/qs-gpu-probe.sh").toString().replace(/^file:\/\//, "")
    readonly property bool gpuCollectorRunning: gpuProcess.running
    readonly property bool gpuDisplayModelReady: gpuStatus === "ok" && gpuProvider !== ""
    readonly property int maxSamples: 30

    function pushSample(history, value) {
        var next = history.slice()
        next.push(Math.max(0, Math.min(1, value / 100)))
        if (next.length > maxSamples) next.shift()
        return next
    }

    function refresh() {
        if (!enabled) return
        if (!metricsProcess.running) metricsProcess.running = true
        if (!gpuProcess.running) gpuProcess.running = true
    }

    function parseGpu(text) {
        gpuStdoutBytes = text.length
        var record
        try {
            record = JSON.parse(text.trim())
        } catch (e) {
            gpuParseStatus = "parse-failed"
            gpuErrorCode = "invalid-json"
            console.warn("Rise GPU collector returned invalid JSON (" + text.length + " bytes)")
            return
        }
        if (record.schemaVersion !== 1 || typeof record.status !== "string") {
            gpuParseStatus = "parse-failed"
            gpuErrorCode = "invalid-schema"
            return
        }
        gpuParseStatus = "ok"
        gpuStatus = record.status
        gpuErrorCode = record.errorCode || ""
        gpuCollectedAt = record.collectedAt || ""
        if (record.status !== "ok") return
        gpuProvider = record.provider || ""
        gpuDevice = record.device || ""
        gpuName = record.name || ""
        gpuTemperatureC = record.temperatureC
        gpuUsagePercent = record.usagePercent
        gpuVramUsedMiB = record.vramUsedMiB
        gpuVramTotalMiB = record.vramTotalMiB
        gpuClockMHz = record.clockMHz
        gpuPowerWatts = record.powerWatts
        if (gpuUsagePercent !== null)
            gpuHistory = pushSample(gpuHistory, gpuUsagePercent)
    }

    property Process metricsProcess: Process {
        command: ["bash", "-c",
            "read _ u1 n1 s1 i1 w1 q1 sq1 st1 _ < /proc/stat; sleep 0.5; " +
            "read _ u2 n2 s2 i2 w2 q2 sq2 st2 _ < /proc/stat; " +
            "di=$(((i2+w2)-(i1+w1))); dn=$(((u2+n2+s2+q2+sq2+st2)-(u1+n1+s1+q1+sq1+st1))); dt=$((di+dn)); echo CPU_PCT $((dt>0?100*dn/dt:0)); " +
            "t=$(for f in /sys/class/hwmon/hwmon*/temp*_input /sys/class/thermal/thermal_zone*/temp; do [ -r \"$f\" ] || continue; d=${f%/*}; n=$(cat \"$d/name\" 2>/dev/null); case \"$n\" in amdgpu|nvidia|nouveau) continue;; esac; v=$(cat \"$f\"); [ \"$v\" -gt 1000 ] 2>/dev/null && v=$((v/1000)); [ \"$v\" -ge 20 ] 2>/dev/null && [ \"$v\" -le 120 ] 2>/dev/null && { echo \"$v\"; break; }; done); echo CPU_TEMP ${t:-0}; " +
            "awk -F: '/cpu MHz/ {s+=$2;n++} END{printf \"CPU_CLOCK %.0f\\n\",n?s/n:0}' /proc/cpuinfo; " +
            "threads=$(nproc); cores=$(awk '/^physical id/{p=$4}/^core id/{print p\":\"$4}' /proc/cpuinfo|sort -u|wc -l); echo CPU_TOPOLOGY ${cores:-0} ${threads:-0}; " +
            "awk '/MemTotal:/{t=$2}/MemAvailable:/{a=$2}END{u=t-a;printf \"RAM %.0f %.0f %.0f\\n\",u,t,t?u*100/t:0}' /proc/meminfo"]
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = text.trim().split("\n")
                for (var i = 0; i < lines.length; ++i) {
                    var p = lines[i].split(/\s+/)
                    if (p[0] === "CPU_PCT") {
                        service.cpuPercent = Number(p[1]) || 0
                        service.cpuHistory = service.pushSample(service.cpuHistory, service.cpuPercent)
                    } else if (p[0] === "CPU_TEMP") service.cpuTemperature = Number(p[1]) || 0
                    else if (p[0] === "CPU_CLOCK") service.cpuClockGHz = (Number(p[1]) || 0) / 1000
                    else if (p[0] === "CPU_TOPOLOGY") { service.cpuCores = Number(p[1]) || 0; service.cpuThreads = Number(p[2]) || 0 }
                    else if (p[0] === "RAM") {
                        service.ramUsedGiB = (Number(p[1]) || 0) / 1048576
                        service.ramTotalGiB = (Number(p[2]) || 0) / 1048576
                        service.ramPercent = Math.round(Number(p[3]) || 0)
                    }
                }
            }
        }
    }

    property Process gpuProcess: Process {
        command: [service.gpuCollectorPath]
        stdout: StdioCollector { onStreamFinished: service.parseGpu(text) }
        onExited: function(exitCode, exitStatus) {
            service.gpuLastExitCode = exitCode
            if (exitCode !== 0) {
                service.gpuStatus = "command-failed"
                service.gpuErrorCode = "exit-" + exitCode
            }
        }
    }

    property Timer metricsTimer: Timer {
        interval: service.panelVisible ? 1500 : 5000
        running: service.enabled
        repeat: true
        triggeredOnStart: true
        onTriggered: service.refresh()
    }
}
