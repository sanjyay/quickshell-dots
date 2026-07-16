import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: rootMod
    required property var root
    property bool recording: false
    property bool stopInFlight: false
    property int  elapsed:   0   // seconds

    function pad(n) { return n < 10 ? "0" + n : String(n) }

    visible: implicitWidth > 0.5
    implicitWidth: recording ? row.implicitWidth + 6 : 0
    clip: true
    implicitHeight: 32
    width: implicitWidth
    height: implicitHeight
    opacity: recording ? 1 : 0


    readonly property string elapsedStr: {
        var h = Math.floor(elapsed / 3600)
        var m = Math.floor((elapsed % 3600) / 60)
        var s = elapsed % 60
        return h > 0 ? (h + ":" + pad(m) + ":" + pad(s)) : (pad(m) + ":" + pad(s))
    }
    readonly property string compactElapsedStr: {
        var totalMinutes = Math.floor(elapsed / 60)
        var s = elapsed % 60
        return totalMinutes + ":" + pad(s)
    }
    readonly property string tooltipText: "Recording · " + elapsedStr + "\nClick to stop"

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 5

        // pulsing record dot
        IconText {
            id: dot
            anchors.verticalCenter: parent.verticalCenter
            text: "\uE061"   // fiber_manual_record
            color: root.seal
            font.pixelSize: 13

            SequentialAnimation on opacity {
                running: rootMod.recording
                loops: Animation.Infinite
                NumberAnimation { to: 0.25; duration: 600; easing.type: Easing.InOutSine }
                NumberAnimation { to: 1.0;  duration: 600; easing.type: Easing.InOutSine }
            }
            // reset opacity when not recording
            onVisibleChanged: if (!rootMod.recording) opacity = 1.0
        }

        UiText {
            anchors.verticalCenter: parent.verticalCenter
            text: rootMod.compactElapsedStr
            color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.82)
            font.family: root.mono
            font.pixelSize: 12
        }
    }

    Process {
        id: recProc
        command: ["bash", "-c",
            "PID=$(pgrep -f '^gpu-screen-recorder' | head -1); " +
            "if [ -n \"$PID\" ]; then echo \"REC $(ps -o etimes= -p $PID 2>/dev/null | tr -d ' ')\"; else echo OFF; fi"
        ]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                var t = this.text.trim()
                if (t.indexOf("REC") === 0) {
                    rootMod.recording = true
                    rootMod.elapsed = parseInt(t.split(" ")[1]) || 0
                } else if (!rootMod.stopInFlight) {
                    rootMod.recording = false
                    rootMod.elapsed = 0
                }
            }
        }
    }

    Timer {
        // poll fast only while recording (live elapsed); slow when idle — just detects an
        // externally-started recording within ~2s. Cuts the always-on 1s idle poll (F7-class).
        interval: rootMod.recording ? 1000 : 2000
        running: true; repeat: true; triggeredOnStart: true
        onTriggered: { recProc.running = false; recProc.running = true }
    }

    Process {
        id: toggleProc
        command: ["omarchy-capture-screenrecording", "--stop-recording"]
        onExited: function(code) {
            rootMod.stopInFlight = false
            if (code === 0) {
                rootMod.recording = false
                rootMod.elapsed = 0
            }
            recProc.running = false
            recProc.running = true
            if (code !== 0)
                console.warn("ScreenRecordWidget: stop command exited with code " + code)
        }
    }

    TooltipMixin { id: tip; root: rootMod.root; owner: rootMod; text: rootMod.tooltipText }

    BarWidgetButton {
        id: recordButton
        theme: rootMod.root
        traceName: "recording-timer-handler"
        anchors.fill: parent
        enabled: rootMod.recording && !rootMod.stopInFlight
        preventStealing: true
        hoverEnabled: true; cursorShape: Qt.PointingHandCursor
        onEntered: tip.show()
        onExited: tip.hide()
        onClicked: {
            tip.hide()
            if (!rootMod.recording || rootMod.stopInFlight) return
            rootMod.stopInFlight = true
            toggleProc.running = false
            toggleProc.running = true
        }
    }
}
