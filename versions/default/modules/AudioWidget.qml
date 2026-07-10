import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: rootMod
    objectName: "volume-wrapper"
    required property var root

    AudioData { id: audio; poll: true }
    readonly property int    volume:   audio.volume
    readonly property bool   muted:    audio.muted

    readonly property string tooltipText: muted
        ? "Muted · " + volume + "%"
        : "Audio " + volume + "%"

    visible: implicitWidth > 0.5
    implicitWidth: root.modVolume ? row.implicitWidth + 18 : 0
    implicitHeight: 28
    width: implicitWidth
    height: implicitHeight
    opacity: root.modVolume ? 1 : 0
    Behavior on opacity      { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

    Rectangle {
        x: 0; anchors.verticalCenter: parent.verticalCenter
        width: Math.round(row.width) + 18
        height: root.pillH
        radius: root.pillRadius
        color: root.pill
        border.color: root.pillBorder
        border.width: root.pillBorderW
        PillShadow { theme: root }
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 5

        UiText {
            anchors.verticalCenter: parent.verticalCenter
            text: "VOL"
            color: rootMod.muted
                ? Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.25)
                : Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.6)
            font.family: root.mono
            font.pixelSize: 12
            font.letterSpacing: 0.5
        }

        // ── workspace-capsule style slider ──
        Item {
            id: slider
            width: 34
            height: 14
            anchors.verticalCenter: parent.verticalCenter

            readonly property real ratio: rootMod.muted ? 0 : Math.min(rootMod.volume / 100, 1)

            // track capsule
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                height: 8
                radius: 4
                color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.18)
            }

            // fill capsule — seal pill like the active workspace
            Rectangle {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: Math.max(slider.ratio > 0 ? 8 : 0, parent.width * slider.ratio)
                height: 8
                radius: 4
                color: root.seal
                Behavior on width { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
            }
        }

        UiText {
            anchors.verticalCenter: parent.verticalCenter
            text: String(rootMod.volume).padStart(2, '0') + "%"
            color: rootMod.muted
                ? Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.35)
                : root.seal
            font.family: root.mono
            font.pixelSize: 12
        }
    }

    TooltipMixin { id: tip; root: rootMod.root; owner: rootMod; text: rootMod.tooltipText }

    property bool audioErrorNotified: false
    function notifyAudioError(action, exitCode) {
        if (exitCode === 0 || audioErrorNotified) return
        audioErrorNotified = true
        audioErrNotify.command = ["bash", "-c",
            "notify-send -a 'QS-Shell' 'Audio command failed' '" + action + " failed; pamixer may be missing.' 2>/dev/null || true"]
        audioErrNotify.running = false
        audioErrNotify.running = true
    }

    Process { id: audioErrNotify }
    Process { id: muteRunner;    command: ["bash", "-c", "pamixer -t"];          onExited: (code) => rootMod.notifyAudioError("Mute", code) }
    Process { id: volUpRunner;   command: ["bash", "-c", "pamixer --increase 5"]; onExited: (code) => rootMod.notifyAudioError("Volume up", code) }
    Process { id: volDownRunner; command: ["bash", "-c", "pamixer --decrease 5"]; onExited: (code) => rootMod.notifyAudioError("Volume down", code) }
    Process {
        id: volSetRunner
        property int targetVolume: rootMod.volume
        command: ["bash", "-c", "pamixer --set-volume " + targetVolume + " --unmute"]
        onExited: (code) => {
            rootMod.notifyAudioError("Set volume", code)
            audio.refresh()
        }
    }

    property bool volumeDragged: false
    property real pressX: 0
    property real pressY: 0
    function setVolumeFromPointer(mouseX, mouseY) {
        var p = mapToItem(slider, mouseX, mouseY)
        var ratio = Math.max(0, Math.min(1, p.x / slider.width))
        var nextVolume = Math.round(ratio * 100)
        volSetRunner.targetVolume = nextVolume
        volSetRunner.running = false
        volSetRunner.running = true
    }

    BarWidgetButton {
        anchors.fill: parent
        theme: root
        traceName: "volume-handler"
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onEntered: tip.show()
        onExited: { tip.hide() }
        onWheel: (e) => {
            if (e.angleDelta.y > 0) { volUpRunner.running = false; volUpRunner.running = true }
            else                    { volDownRunner.running = false; volDownRunner.running = true }
            audio.refresh()
        }
        onPressed: (e) => {
            rootMod.pressX = e.x
            rootMod.pressY = e.y
            rootMod.volumeDragged = false
        }
        onPositionChanged: (e) => {
            if (!(pressedButtons & Qt.LeftButton)) return
            if (Math.abs(e.x - rootMod.pressX) < 3 && Math.abs(e.y - rootMod.pressY) < 3) return
            rootMod.volumeDragged = true
            rootMod.setVolumeFromPointer(e.x, e.y)
        }
        onReleased: (e) => {
            if (rootMod.volumeDragged && e.button === Qt.LeftButton) {
                rootMod.setVolumeFromPointer(e.x, e.y)
                tip.hide()
            }
        }
        onClicked: (e) => {
            if (rootMod.volumeDragged) return
            tip.hide()
            if (e.button === Qt.RightButton) { muteRunner.running = false; muteRunner.running = true }
            else                             { root.volVisible = !root.volVisible }
        }
    }
}
