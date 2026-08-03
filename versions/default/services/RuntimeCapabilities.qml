import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: service

    readonly property string holidayHelperPath: {
        var value = String(Qt.resolvedUrl("../../../scripts/holiday-helper.js"))
        return value.indexOf("file://") === 0 ? value.substring(7) : value
    }
    property bool probed: false
    property int probeCount: 0
    property string probeError: ""
    property string probeOutput: ""
    property var values: ({})

    readonly property bool node: available("node")
    readonly property bool holidayRuntimeData: available("holidayRuntimeData")
    readonly property bool dateHolidays: available("dateHolidays")
    readonly property bool python: available("python3")
    readonly property bool claudeCli: available("claude")
    readonly property bool codexCli: available("codex")
    readonly property bool openCodeCli: available("opencode")
    readonly property bool tailscale: available("tailscale")
    readonly property bool powerProfiles: available("powerprofilesctl")
    readonly property bool gpuProbe: available("gpuProbe")
    readonly property bool networkManager: available("nmcli")
    readonly property bool bluetooth: available("bluetoothctl")
    readonly property bool systemdUser: available("systemdUser")

    function available(name) {
        return values[name] && values[name].available === true
    }

    function diagnosticsObject() {
        return { probed: probed, probeCount: probeCount, error: probeError || null,
            capabilities: values }
    }

    function refresh() {
        if (probe.running) return false
        probeOutput = ""
        probeCount++
        probe.command = ["bash", "-c", [
            "set +e",
            "for c in node python3 claude codex opencode tailscale powerprofilesctl nmcli bluetoothctl; do",
            "  command -v \"$c\" >/dev/null 2>&1 && printf '%s=1\\n' \"$c\" || printf '%s=0\\n' \"$c\"",
            "done",
            "if command -v lspci >/dev/null 2>&1 || command -v nvidia-smi >/dev/null 2>&1 || command -v rocm-smi >/dev/null 2>&1; then printf 'gpuProbe=1\\n'; else printf 'gpuProbe=0\\n'; fi",
            "systemctl --user show-environment >/dev/null 2>&1 && printf 'systemdUser=1\\n' || printf 'systemdUser=0\\n'",
            "if command -v node >/dev/null 2>&1; then",
            "  result=$(node \"$1\" dependency-status 2>/dev/null)",
            "  printf '%s' \"$result\" | grep -q '\"available\":true' && printf 'dateHolidays=1\\nholidayRuntimeData=1\\n' || printf 'dateHolidays=0\\nholidayRuntimeData=0\\n'",
            "else printf 'dateHolidays=0\\nholidayRuntimeData=0\\n'; fi"
        ].join("\n"), "astra-capabilities", holidayHelperPath]
        probe.running = true
        return true
    }

    Component.onCompleted: refresh()

    property Process probe: Process {
        stdout: StdioCollector { onStreamFinished: service.probeOutput = text }
        onExited: function(exitCode) {
            var parsed = {}
            var lines = service.probeOutput.split(/\r?\n/)
            for (var i = 0; i < lines.length; i++) {
                var match = lines[i].match(/^([A-Za-z0-9]+)=([01])$/)
                if (match) parsed[match[1]] = { available: match[2] === "1" }
            }
            service.values = parsed
            service.probeError = exitCode === 0 ? "" : "capability probe exited " + exitCode
            service.probed = true
        }
    }
}
