import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: rootMod
    required property var root

    property bool updateAvailable: false
    property bool checking: false
    onUpdateAvailableChanged: {
        root.omarchyUpdateAvail = updateAvailable   // mirror for the swarm reactor
        if (updateAvailable) updateTimer.restart()
    }

    visible: updateAvailable
    implicitWidth: updateAvailable ? 20 : 0
    implicitHeight: 28
    width: implicitWidth
    height: implicitHeight


    readonly property string tooltipText: "Omarchy update available"

    IconText {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: 2
        text: "\uE627"   // sync
        color: root.seal
        font.pixelSize: 14
    }

    Process {
        id: updateProc
        command: ["bash", "-c", "omarchy-update-available >/dev/null 2>&1 && echo YES || echo NO"]
        running: false
        onRunningChanged: if (running) {
            rootMod.checking = true
            rootMod.updateAvailable = false
        }
        stdout: StdioCollector {
            onStreamFinished: {
                rootMod.updateAvailable = this.text.trim() === "YES"
                rootMod.checking = false
            }
        }
        onExited: rootMod.checking = false
    }

    Timer {
        id: updateTimer
        interval: rootMod.updateAvailable ? 60000 : 21600000   // recheck active badges every minute
        running: true; repeat: true; triggeredOnStart: true
        onTriggered: { updateProc.running = false; updateProc.running = true }
    }

    Process { id: runProc; command: ["bash", "-c", "omarchy-launch-floating-terminal-with-presentation omarchy-update"] }

    TooltipMixin { id: tip; root: rootMod.root; owner: rootMod; text: rootMod.tooltipText }

    BarWidgetButton {
        anchors.fill: parent
        hoverEnabled: true; cursorShape: Qt.PointingHandCursor
        onEntered: tip.show()
        onExited:  { tip.hide() }
        onClicked: {
            tip.hide()
            runProc.running = false; runProc.running = true
        }
    }
}
