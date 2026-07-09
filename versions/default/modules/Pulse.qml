import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: island
    required property var root
    property var cameraSwitch: null

    width: pill.width
    height: 44
    visible: root.enablePulse && reveal > 0.01
    opacity: reveal
    scale: 0.94 + reveal * 0.06
    z: 80

    property real reveal: 0
    property string title: ""
    property string detail: ""
    property string lastTrack: ""
    property bool lastMicLive: false
    property bool lastCameraBlocked: false
    property int lastBrightness: -1

    MprisSelect { id: mpris }

    Behavior on reveal { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
    Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

    function flash(t, d) {
        if (!root.enablePulse) return
        title = t
        detail = d
        reveal = 1
        hideTimer.restart()
    }

    Timer {
        id: hideTimer
        interval: 1800
        repeat: false
        onTriggered: island.reveal = 0
    }

    Connections {
        target: mpris
        function onPlayerChanged() { island.checkTrack() }
        function onActiveChanged() { island.checkTrack() }
    }

    Timer {
        interval: 1200
        running: root.enablePulse
        repeat: true
        triggeredOnStart: true
        onTriggered: island.checkTrack()
    }

    function checkTrack() {
        if (!mpris.player || !mpris.active) return
        var track = (mpris.player.trackTitle || "") + " - " + (mpris.player.trackArtist || "")
        if (track !== " - " && track !== lastTrack) {
            lastTrack = track
            flash("Now playing", track)
        }
    }

    Process {
        id: micProc
        command: ["bash", "-c", "pactl list source-outputs short 2>/dev/null | wc -l"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                var live = (parseInt(this.text.trim()) || 0) > 0
                if (live !== island.lastMicLive) {
                    island.lastMicLive = live
                    island.flash("Microphone", live ? "active" : "idle")
                }
            }
        }
    }

    Process {
        id: brightnessProc
        command: ["bash", "-c",
            "for d in /sys/class/backlight/*; do " +
            "  [ -r \"$d/brightness\" ] && [ -r \"$d/max_brightness\" ] || continue; " +
            "  b=$(cat \"$d/brightness\" 2>/dev/null); m=$(cat \"$d/max_brightness\" 2>/dev/null); " +
            "  [ \"${m:-0}\" -gt 0 ] 2>/dev/null || continue; " +
            "  echo $((100*b/m)); exit; " +
            "done"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                var v = parseInt(this.text.trim())
                if (isNaN(v)) return
                if (island.lastBrightness >= 0 && Math.abs(v - island.lastBrightness) >= 2)
                    island.flash("Brightness", v + "%")
                island.lastBrightness = v
            }
        }
    }

    Timer {
        interval: 2000
        running: root.enablePulse
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            micProc.running = false
            micProc.running = true
            brightnessProc.running = false
            brightnessProc.running = true
            var blocked = island.cameraSwitch && island.cameraSwitch.stateKnown && !island.cameraSwitch.cameraEnabled
            if (blocked !== island.lastCameraBlocked) {
                island.lastCameraBlocked = blocked
                island.flash("Camera", blocked ? "blocked" : "enabled")
            }
        }
    }

    Rectangle {
        id: pill
        anchors.centerIn: parent
        width: Math.max(190, Math.min(440, textCol.implicitWidth + 48))
        height: 42
        radius: root.pillRadius
        color: root.barBg
        border.color: Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.55)
        border.width: root.pillBorderW
        PillShadow { theme: root }

        Column {
            id: textCol
            anchors.centerIn: parent
            spacing: 2
            UiText {
                anchors.horizontalCenter: parent.horizontalCenter
                text: island.title
                color: root.seal
                font.family: root.mono
                font.pixelSize: 13
                font.weight: Font.Medium
            }
            UiText {
                anchors.horizontalCenter: parent.horizontalCenter
                width: Math.min(380, implicitWidth)
                text: island.detail
                color: root.ink
                elide: Text.ElideRight
                font.family: root.mono
                font.pixelSize: 11
            }
        }
    }
}
