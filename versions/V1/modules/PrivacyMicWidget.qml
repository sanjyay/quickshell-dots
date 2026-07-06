import QtQuick
import Quickshell
import Quickshell.Io
import "../IconMap.js" as IconMap

Item {
    id: rootMod
    required property var root

    property bool muted: false
    property int activeApps: 0
    readonly property bool live: activeApps > 0
    readonly property bool shown: root.modPrivacy

    visible: shown
    implicitWidth: shown ? row.implicitWidth + 12 : 0
    implicitHeight: 28
    opacity: shown ? 1 : 0

    Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

    readonly property string tooltipText: muted
        ? "Microphone muted"
        : live ? "Microphone active · " + activeApps + " app" + (activeApps === 1 ? "" : "s")
               : "Microphone on"

    Rectangle {
        anchors.centerIn: parent
        width: parent.implicitWidth
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
        spacing: 0

        IconText {
            anchors.verticalCenter: parent.verticalCenter
            text: IconMap.icon(rootMod.muted ? "mic_off" : "mic")
            color: rootMod.live && !rootMod.muted
                ? root.seal
                : Qt.rgba(root.ink.r, root.ink.g, root.ink.b, rootMod.muted ? 0.3 : 0.7)
            font.pixelSize: 13
            Behavior on color { ColorAnimation { duration: 160 } }
        }
    }

    Process {
        id: micProc
        command: ["bash", "-c",
            "muted=$(pactl get-source-mute @DEFAULT_SOURCE@ 2>/dev/null | awk '{print $2}'); " +
            "count=$(pactl list source-outputs short 2>/dev/null | wc -l); " +
            "printf '%s\\t%s\\n' \"${muted:-no}\" \"$count\""
        ]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                var parts = this.text.trim().split("\t")
                rootMod.muted = parts[0] === "yes"
                rootMod.activeApps = parseInt(parts[1]) || 0
            }
        }
    }

    Timer {
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: { micProc.running = false; micProc.running = true }
    }

    Process {
        id: toggleProc
        command: ["bash", "-c",
            "wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle 2>/dev/null || " +
            "pactl set-source-mute @DEFAULT_SOURCE@ toggle 2>/dev/null"]
        running: false
        onExited: { micProc.running = false; micProc.running = true }
    }

    TooltipMixin { id: tip; root: rootMod.root; owner: rootMod; text: rootMod.tooltipText }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onEntered: tip.show()
        onExited: tip.hide()
        onClicked: {
            tip.hide()
            toggleProc.running = false
            toggleProc.running = true
        }
    }
}
