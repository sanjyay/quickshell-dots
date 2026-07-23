import QtQuick
import Quickshell.Io

QtObject {
    id: service

    property bool enabled: true
    property bool panelVisible: false
    property int cpuPercent: 0
    property int cpuTemperature: 0
    property var cpuHistory: []
    property string gpuDriver: ""
    property int gpuUtilization: 0
    property int gpuTemperature: 0
    property int gpuMemoryUsed: 0
    property int gpuMemoryTotal: 0
    property bool gpuMemoryAvailable: false
    property var gpuHistory: []
    property int ramPercent: 0
    property real ramUsedGiB: 0
    property real ramTotalGiB: 0
    readonly property int maxSamples: 30

    function pushSample(history, value) {
        var next = history.slice()
        next.push(Math.max(0, Math.min(1, value / 100)))
        if (next.length > maxSamples) next.shift()
        return next
    }

    function refresh() {
        metricsProcess.running = false
        metricsProcess.running = true
    }

    property Process metricsProcess: Process {
        command: ["bash", "-c",
            "read _ u1 n1 s1 i1 w1 q1 sq1 st1 _ < /proc/stat && " +
            "sleep 0.5 && " +
            "read _ u2 n2 s2 i2 w2 q2 sq2 st2 _ < /proc/stat && " +
            "di=$(( (i2+w2)-(i1+w1) )) && " +
            "dn=$(( (u2+n2+s2+q2+sq2+st2)-(u1+n1+s1+q1+sq1+st1) )) && " +
            "dt=$((di+dn)) && echo CPU_PCT $((dt>0?100*dn/dt:0)); " +
            "cpu_temp(){ best=0; " +
            "for f in /sys/class/hwmon/hwmon*/temp*_input /sys/class/thermal/thermal_zone*/temp; do " +
            "[ -r \"$f\" ] || continue; dir=${f%/*}; name=$(cat \"$dir/name\" 2>/dev/null); " +
            "case \"$name\" in amdgpu|nvidia|nouveau) continue;; esac; " +
            "v=$(cat \"$f\" 2>/dev/null); [ -n \"$v\" ] || continue; [ \"$v\" -gt 1000 ] 2>/dev/null && v=$((v/1000)); " +
            "[ \"$v\" -ge 20 ] 2>/dev/null && [ \"$v\" -le 120 ] 2>/dev/null || continue; " +
            "label=${f%_input}_label; label=$(cat \"$label\" 2>/dev/null); " +
            "echo \"$label $name\" | grep -Eiq 'cpu|package|tctl|tdie|core 0' && { echo \"$v\"; return; }; " +
            "[ \"$v\" -gt \"$best\" ] 2>/dev/null && best=$v; done; echo \"$best\"; }; " +
            "echo CPU_TEMP $(cpu_temp); " +
            "awk '/MemTotal:/ {t=$2} /MemAvailable:/ {a=$2} END{u=t-a; printf \"RAM %.0f %.0f %.0f\\n\", u, t, (t>0?u*100/t:0)}' /proc/meminfo; " +
            "p=\"$HOME/.config/quickshell/bar/modules/qs-gpu-probe.sh\"; " +
            "[ -x \"$p\" ] || p=\"versions/default/modules/qs-gpu-probe.sh\"; \"$p\""]
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = this.text.trim().split("\n")
                service.gpuDriver = ""
                service.gpuMemoryAvailable = false
                for (var i = 0; i < lines.length; i++) {
                    var parts = lines[i].trim().split(/\s+/)
                    if (parts[0] === "CPU_PCT" && parts.length >= 2) {
                        service.cpuPercent = Math.max(0, Math.min(100, parseInt(parts[1]) || 0))
                        service.cpuHistory = service.pushSample(service.cpuHistory, service.cpuPercent)
                    } else if (parts[0] === "CPU_TEMP" && parts.length >= 2) {
                        service.cpuTemperature = Math.max(0, parseInt(parts[1]) || 0)
                    } else if (parts[0] === "RAM" && parts.length >= 4) {
                        var usedKB = parseFloat(parts[1]) || 0
                        var totalKB = parseFloat(parts[2]) || 0
                        service.ramUsedGiB = usedKB / (1024 * 1024)
                        service.ramTotalGiB = totalKB / (1024 * 1024)
                        service.ramPercent = Math.max(0, Math.min(100, Math.round(parseFloat(parts[3]) || 0)))
                    } else if (parts[0] === "GPU" && parts.length >= 6) {
                        service.gpuDriver = parts[1]
                        service.gpuUtilization = parts[2] === "--" ? 0 : (parseInt(parts[2]) || 0)
                        service.gpuTemperature = parts[3] === "--" ? 0 : Math.max(0, parseInt(parts[3]) || 0)
                        service.gpuMemoryAvailable = parts[4] !== "--" && parts[5] !== "--"
                        service.gpuMemoryUsed = service.gpuMemoryAvailable ? (parseInt(parts[4]) || 0) : 0
                        service.gpuMemoryTotal = service.gpuMemoryAvailable ? (parseInt(parts[5]) || 0) : 0
                        service.gpuHistory = service.pushSample(service.gpuHistory, service.gpuUtilization)
                    }
                }
            }
        }
    }

    property Timer metricsTimer: Timer {
        interval: service.panelVisible ? 1500 : 2000
        running: service.enabled || service.panelVisible
        repeat: true
        triggeredOnStart: true
        onTriggered: service.refresh()
    }
}
