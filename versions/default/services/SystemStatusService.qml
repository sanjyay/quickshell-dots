import QtQuick
import Quickshell.Io

QtObject {
    id: service

    property bool notificationSilenced: false
    property bool idleAwake: false
    property bool privacyMicMuted: false
    property int privacyMicActiveApps: 0
    property bool screenRecording: false
    property bool screenRecordingStopInFlight: false
    property int screenRecordingElapsed: 0
    property string voxtypeState: "idle"
    property string voxtypeHint: ""
    property bool hasVoxtype: true
    property string powerProfileCurrent: ""
    property bool powerProfileEnabled: false
    property bool powerProfileVisible: false
    property bool bluetoothOn: false
    property int bluetoothConnectedCount: 0

    function restart(process) {
        process.running = false
        process.running = true
    }

    function refreshNotificationSilence() { restart(notificationSilenceReadProc) }
    function toggleNotificationSilence() { restart(notificationSilenceToggleProc) }
    function refreshIdleState() { restart(idleStateReadProc) }
    function toggleIdleState() { restart(idleStateToggleProc) }
    function refreshPrivacyMic() { restart(privacyMicReadProc) }
    function togglePrivacyMic() { restart(privacyMicToggleProc) }
    function refreshScreenRecording() { restart(screenRecordingReadProc) }
    function refreshVoxtype() { restart(voxtypeReadProc) }
    function refreshPowerProfile() { restart(powerProfileReadProc) }
    function refreshBluetoothSummary() {
        bluetoothSummaryProc.result = ""
        restart(bluetoothSummaryProc)
    }

    function stopScreenRecording() {
        if (!screenRecording || screenRecordingStopInFlight) return
        screenRecordingStopInFlight = true
        restart(screenRecordingStopProc)
    }

    function setPowerProfile(profile) {
        powerProfileSetProc.command = ["bash", "-c", "powerprofilesctl set " + profile]
        restart(powerProfileSetProc)
        powerProfileCurrent = profile
    }

    property Process notificationSilenceReadProc: Process {
        command: ["bash", "-c", "qs-notification-silence status"]
        stdout: StdioCollector {
            onStreamFinished: service.notificationSilenced = this.text.trim() === "ON"
        }
    }
    property Process notificationSilenceToggleProc: Process {
        command: ["bash", "-c", "qs-notification-silence toggle"]
        onRunningChanged: if (!running) service.refreshNotificationSilence()
    }
    property Timer notificationSilenceTimer: Timer {
        interval: 2000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: service.refreshNotificationSilence()
    }

    property Process idleStateReadProc: Process {
        command: ["bash", "-c", "pgrep -x hypridle >/dev/null && echo ON || echo OFF"]
        stdout: StdioCollector {
            onStreamFinished: service.idleAwake = this.text.trim() === "OFF"
        }
    }
    property Process idleStateToggleProc: Process {
        command: ["bash", "-c", "omarchy-toggle-idle"]
        onRunningChanged: if (!running) service.refreshIdleState()
    }
    property Timer idleStateTimer: Timer {
        interval: 2000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: service.refreshIdleState()
    }

    property Process privacyMicReadProc: Process {
        command: ["bash", "-c",
            "muted=$(pactl get-source-mute @DEFAULT_SOURCE@ 2>/dev/null | awk '{print $2}'); " +
            "count=$(pactl list source-outputs short 2>/dev/null | wc -l); " +
            "printf '%s\\t%s\\n' \"${muted:-no}\" \"$count\""]
        stdout: StdioCollector {
            onStreamFinished: {
                var parts = this.text.trim().split("\t")
                service.privacyMicMuted = parts[0] === "yes"
                service.privacyMicActiveApps = parseInt(parts[1]) || 0
            }
        }
    }
    property Process privacyMicToggleProc: Process {
        command: ["bash", "-c",
            "wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle 2>/dev/null || " +
            "pactl set-source-mute @DEFAULT_SOURCE@ toggle 2>/dev/null"]
        onRunningChanged: if (!running) service.refreshPrivacyMic()
    }
    property Timer privacyMicTimer: Timer {
        interval: 2000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: service.refreshPrivacyMic()
    }

    property Process screenRecordingReadProc: Process {
        command: ["bash", "-c",
            "PID=$(pgrep -f '^gpu-screen-recorder' | head -1); " +
            "if [ -n \"$PID\" ]; then echo \"REC $(ps -o etimes= -p $PID 2>/dev/null | tr -d ' ')\"; else echo OFF; fi"]
        stdout: StdioCollector {
            onStreamFinished: {
                var value = this.text.trim()
                if (value.indexOf("REC") === 0) {
                    service.screenRecording = true
                    service.screenRecordingElapsed = parseInt(value.split(" ")[1]) || 0
                } else if (!service.screenRecordingStopInFlight) {
                    service.screenRecording = false
                    service.screenRecordingElapsed = 0
                }
            }
        }
    }
    property Timer screenRecordingTimer: Timer {
        interval: service.screenRecording ? 1000 : 2000
        running: true; repeat: true; triggeredOnStart: true
        onTriggered: service.refreshScreenRecording()
    }
    property Process screenRecordingStopProc: Process {
        command: ["omarchy-capture-screenrecording", "--stop-recording"]
        onExited: function(code) {
            service.screenRecordingStopInFlight = false
            if (code === 0) {
                service.screenRecording = false
                service.screenRecordingElapsed = 0
            }
            service.refreshScreenRecording()
            if (code !== 0) console.warn("Screen recording stop command exited with code " + code)
        }
    }

    property Process voxtypeReadProc: Process {
        command: ["bash", "-c",
            "if command -v voxtype >/dev/null 2>&1; then " +
            "timeout 1 voxtype status --extended --format json 2>/dev/null | jq -r '[(.class // .alt // \"idle\"), ((.tooltip // \"\") | split(\"\\n\")[0])] | @tsv' 2>/dev/null; " +
            "else echo 'MISSING'; fi"]
        stdout: StdioCollector {
            onStreamFinished: {
                var parts = this.text.trim().split("\t")
                if (parts[0] === "MISSING") {
                    service.hasVoxtype = false
                    service.voxtypeState = "idle"
                    service.voxtypeHint = ""
                    return
                }
                service.voxtypeState = parts[0] || "idle"
                service.voxtypeHint = parts[1] || ""
            }
        }
    }
    property Timer voxtypeTimer: Timer {
        interval: 1000; running: service.hasVoxtype; repeat: true; triggeredOnStart: true
        onTriggered: service.refreshVoxtype()
    }

    property Process powerProfileReadProc: Process {
        command: ["bash", "-c", "powerprofilesctl get 2>/dev/null || echo balanced"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                var profile = this.text.trim()
                if (profile) service.powerProfileCurrent = profile
            }
        }
    }
    property Timer powerProfileTimer: Timer {
        interval: 5000
        running: service.powerProfileEnabled || service.powerProfileVisible
        repeat: true
        triggeredOnStart: true
        onTriggered: service.refreshPowerProfile()
    }
    property Process powerProfileSetProc: Process {
        command: ["bash", "-c", "powerprofilesctl set balanced"]
    }

    property Process bluetoothSummaryProc: Process {
        property string result: ""
        command: ["bash", "-c",
            "if bluetoothctl show 2>/dev/null | grep -q 'Powered: yes'; then " +
            "COUNT=$(bluetoothctl devices Connected 2>/dev/null | wc -l); printf 'ON\\t%s\\n' \"$COUNT\"; " +
            "else echo OFF; fi"]
        stdout: SplitParser {
            onRead: function(line) { bluetoothSummaryProc.result = line.trim() }
        }
        onExited: {
            var value = bluetoothSummaryProc.result
            if (value === "OFF" || value === "") {
                service.bluetoothOn = false
                service.bluetoothConnectedCount = 0
            } else if (value.startsWith("ON\t")) {
                service.bluetoothOn = true
                service.bluetoothConnectedCount = parseInt(value.split("\t")[1]) || 0
            }
            bluetoothSummaryProc.result = ""
        }
    }
    property Timer bluetoothSummaryTimer: Timer {
        interval: 5000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: service.refreshBluetoothSummary()
    }
}
