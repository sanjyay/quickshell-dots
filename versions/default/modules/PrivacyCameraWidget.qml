import QtQuick
import Quickshell
import Quickshell.Io
import "../IconMap.js" as IconMap

Item {
    id: rootMod
    required property var root

    property bool hasCamera: false
    property bool blocked: false
    property int activeApps: 0
    readonly property bool live: activeApps > 0
    readonly property bool shown: root.modPrivacy

    visible: shown
    implicitWidth: shown ? row.implicitWidth + 12 : 0
    implicitHeight: 28
    opacity: shown ? 1 : 0

    Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

    readonly property string tooltipText: !hasCamera
        ? "No camera found"
        : blocked ? "Camera blocked"
                  : live ? "Camera active · " + activeApps + " process" + (activeApps === 1 ? "" : "es")
                         : "Camera on"

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
            text: IconMap.icon(rootMod.blocked ? "videocam_off" : "videocam")
            color: rootMod.live && !rootMod.blocked
                ? root.seal
                : Qt.rgba(root.ink.r, root.ink.g, root.ink.b, rootMod.blocked || !rootMod.hasCamera ? 0.3 : 0.7)
            font.pixelSize: 13
            Behavior on color { ColorAnimation { duration: 160 } }
        }
    }

    Process {
        id: camProc
        command: ["bash", "-c",
            "marker=\"$HOME/.cache/quickshell_camera_blocked\"; " +
            "set -- /dev/video*; [ -e \"$1\" ] || { echo NONE; exit 0; }; " +
            "blocked=0; [ -e \"$marker\" ] && blocked=1; " +
            "active=$(fuser /dev/video* 2>/dev/null | tr ' ' '\\n' | grep -c '^[0-9]'); " +
            "printf 'CAM\\t%s\\t%s\\n' \"$blocked\" \"$active\""
        ]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                var parts = this.text.trim().split("\t")
                rootMod.hasCamera = parts[0] === "CAM"
                rootMod.blocked = rootMod.hasCamera && parts[1] === "1"
                rootMod.activeApps = rootMod.hasCamera ? (parseInt(parts[2]) || 0) : 0
            }
        }
    }

    Timer {
        interval: 2500
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: { camProc.running = false; camProc.running = true }
    }

    Process {
        id: toggleProc
        command: ["bash", "-c",
            "marker=\"$HOME/.cache/quickshell_camera_blocked\"; " +
            "inner='set -- /dev/video*; [ -e \"$1\" ] || { echo \"No camera devices found.\"; sleep 1; exit 0; }; " +
            "if [ -e \"$HOME/.cache/quickshell_camera_blocked\" ]; then " +
            "sudo chmod g+rw /dev/video*; rm -f \"$HOME/.cache/quickshell_camera_blocked\"; echo Camera enabled.; " +
            "else sudo chmod g-rw,o-rw /dev/video*; touch \"$HOME/.cache/quickshell_camera_blocked\"; echo Camera blocked.; fi; sleep 1'; " +
            "omarchy-launch-floating-terminal-with-presentation \"$inner\""]
        running: false
        onExited: { camProc.running = false; camProc.running = true }
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
