import QtQuick
import Quickshell.Io

// Shared default-sink probe: volume / muted / output-port type.
// Used by AudioWidget (poll: true → refresh every `interval`) and by
// VolumePanel (on-demand via refresh() when it opens). Centralizes the
// pactl command + parsing that previously lived duplicated in both files.
Item {
    id: audio

    property bool poll:     false   // auto-refresh on a timer when true
    property int  interval: 3000

    property int    volume:   50
    property bool   muted:    false
    property string portType: "default"

    function refresh() { proc.lines = []; proc.running = false; proc.running = true }

    Process {
        id: proc
        running: false
        // one pactl call, exact sink match, real active port (the old grep -A80 could
        // miss the port or bleed into the next sink's block — returned empty on some setups)
        command: ["bash", "-c",
            "export LC_ALL=C; def=$(pactl get-default-sink); " +
            "pactl -f json list sinks 2>/dev/null | jq -r --arg n \"$def\" '.[]|select(.name==$n)|(.volume|to_entries[0].value.value_percent|rtrimstr(\"%\")),(if .mute then \"yes\" else \"no\" end),(.active_port // \"-\")'"
        ]
        stdout: SplitParser {
            onRead: function(line) { proc.lines.push(line.trim()) }
        }
        onExited: {
            if (proc.lines.length >= 2) {
                audio.volume = parseInt(proc.lines[0]) || 0
                audio.muted  = (proc.lines[1] === "yes")
                var port = proc.lines[2] || ""
                if (port.includes("headphone"))    audio.portType = "headphone"
                else if (port.includes("headset")) audio.portType = "headset"
                else                               audio.portType = "default"
            }
            proc.lines = []
        }
        property var lines: []
    }

    Timer {
        interval: audio.interval; running: audio.poll; repeat: true; triggeredOnStart: true
        onTriggered: audio.refresh()
    }
}
