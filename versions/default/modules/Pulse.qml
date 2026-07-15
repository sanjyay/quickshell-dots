import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: island
    required property var root
    property var cameraSwitch: null
    property alias inputItem: pulseButton

    width: pill.width
    height: 44
    visible: root.enablePulse && reveal > 0.01
    opacity: reveal
    scale: 0.94 + reveal * 0.06
    z: 80

    Component.onCompleted: if (root.pointerTrace)
        console.log("POINTER_PULSE visible=" + island.visible + " reveal=" + island.reveal
            + " scene=" + island.mapToItem(null, 0, 0).x + "," + island.mapToItem(null, 0, 0).y
            + " size=" + island.width + "x" + island.height + " hint=" + island.hint)
    onVisibleChanged: if (root.pointerTrace)
        console.log("POINTER_PULSE visible=" + island.visible + " reveal=" + island.reveal
            + " scene=" + island.mapToItem(null, 0, 0).x + "," + island.mapToItem(null, 0, 0).y
            + " size=" + island.width + "x" + island.height + " hint=" + island.hint)

    property real reveal: 0
    property string title: ""
    property string detail: ""
    property string hint: ""
    property string lastTrack: ""
    property bool lastMicLive: false
    property bool lastCameraBlocked: false
    property int lastBrightness: -1
    property int lastNotificationSerial: -1

    MprisSelect { id: mpris }

    Behavior on reveal { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
    Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

    function flash(t, d, h, durationMs) {
        if (!root.enablePulse) return
        title = t
        detail = d
        hint = h || ""
        reveal = 1
        hideTimer.interval = durationMs || 1800
        hideTimer.restart()
    }

    Timer {
        id: hideTimer
        interval: 1800
        repeat: false
        onTriggered: {
            island.reveal = 0
            if (root.osdVisible) root.osdVisible = false
        }
    }

    Connections {
        target: root
        function onUpdatePulseSerialChanged() {
            island.flash(root.updatePulseTitle, root.updatePulseDetail, root.updatePulseHint, 7000)
        }
    }

    Connections {
        target: root
        function onOsdSerialChanged() {
            var title = ""
            var detail = root.osdValue ? root.osdValue + "%" : ""
            if (root.osdKind === "volume") {
                title = "Volume"
                if (root.osdDetail === "true") detail = "Muted · " + detail
            } else if (root.osdKind === "microphone") {
                title = "Microphone"
                if (root.osdDetail === "true") detail = "Muted · " + detail
            } else if (root.osdKind === "brightness") {
                title = "Brightness"
            } else if (root.osdKind === "keyboard") {
                title = "Keyboard brightness"
            } else if (root.osdKind === "media") {
                title = "Media"
                detail = root.osdDetail || ""
            }
            if (title !== "") island.flash(title, detail, "", 1200)
        }
    }

    Connections {
        target: root
        function onNotifSerialChanged() {
            if (root.notifSerial <= island.lastNotificationSerial) return
            island.lastNotificationSerial = root.notifSerial
            var summary = root.notifLatestSummary || ""
            var body = root.notifLatestBody || ""
            var message = summary && body && body !== summary ? summary + " - " + body : (summary || body)
            if (message !== "") island.flash("Notification", message, root.notifLatestApp || "", 4200)
        }
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
            flash("Now playing", track, "", 1800)
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
                    island.flash("Microphone", live ? "active" : "idle", "", 1800)
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
                    island.flash("Brightness", v + "%", "", 1800)
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
                island.flash("Camera", blocked ? "blocked" : "enabled", "", 1800)
            }
        }
    }

    Rectangle {
        id: pill
        anchors.centerIn: parent
        width: Math.max(190, Math.min(440, textCol.implicitWidth + 48))
        height: island.hint ? 56 : 42
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
            UiText {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: island.hint.length > 0
                text: island.hint
                color: root.sumi
                font.family: root.mono
                font.pixelSize: 10
            }
        }

        BarWidgetButton {
            id: pulseButton
            anchors.fill: parent
            theme: root
            traceName: "pulse-handler"
            visible: island.visible && island.hint.length > 0
            enabled: island.hint.length > 0
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (island.title === "Notification") {
                    var notification = root.notifLatestObject
                    if (notification && notification.actions.length > 0) {
                        var actions = notification.actions
                        var invoked = false
                        for (var i = 0; i < actions.length; i++) {
                            if (actions[i].identifier === "default") {
                                actions[i].invoke()
                                invoked = true
                                break
                            }
                        }
                        if (!invoked) actions[0].invoke()
                    }
                    root.notifLatestObject = null
                } else {
                    root.activeUpdateTab = "packages"
                    root.archVisible = true
                }
                island.reveal = 0
            }
        }
    }
}
