import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: rootMod
    required property var root

    // "stay awake" mode active when hypridle is NOT running
    property bool awake: false

    visible: awake
    implicitWidth: awake ? 20 : 0
    implicitHeight: 28
    width: implicitWidth
    height: implicitHeight


    readonly property string tooltipText: "Idle lock disabled"

    Text {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: 2
        text: "\uF0F4"   // coffee (Nerd Font / JetBrainsMono)
        color: root.seal
        font.family: root.mono
        font.pixelSize: 24
    }

    Process {
        id: idleProc
        command: ["bash", "-c", "pgrep -x hypridle >/dev/null && echo ON || echo OFF"]
        running: false
        stdout: StdioCollector {
            // hypridle ON → normal idle; OFF → stay-awake mode (show icon)
            onStreamFinished: { rootMod.awake = this.text.trim() === "OFF" }
        }
    }

    Timer {
        interval: 2000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: { idleProc.running = false; idleProc.running = true }
    }

    Process { id: toggleProc; command: ["bash", "-c", "omarchy-toggle-idle"] }

    TooltipMixin { id: tip; root: rootMod.root; owner: rootMod; text: rootMod.tooltipText }

    BarWidgetButton {
        anchors.fill: parent
        hoverEnabled: true; cursorShape: Qt.PointingHandCursor
        onEntered: tip.show()
        onExited:  { tip.hide() }
        onClicked: {
            tip.hide()
            toggleProc.running = false; toggleProc.running = true
            Qt.callLater(function() { idleProc.running = false; idleProc.running = true })
        }
    }
}
