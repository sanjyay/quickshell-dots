import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: rootMod
    required property var root
    property var barScreen: null

    property date now: new Date()

    function pad(n) { return n < 10 ? "0" + n : String(n) }

    readonly property string timeStr: {
        if (root.clock12h) {
            var h = now.getHours() % 12; if (h === 0) h = 12
            return h + ":" + pad(now.getMinutes()) + " " + (now.getHours() < 12 ? "AM" : "PM")
        }
        return pad(now.getHours()) + ":" + pad(now.getMinutes())
    }

    readonly property var months: ["January","February","March","April","May","June",
                                    "July","August","September","October","November","December"]
    readonly property var days: ["Sun","Mon","Tue","Wed","Thu","Fri","Sat"]

    readonly property string tooltipText: days[now.getDay()] + ", " + now.getDate() + " " + months[now.getMonth()] + " " + now.getFullYear()
    readonly property string dateStr: days[now.getDay()] + " " + now.getDate()

    implicitWidth: clockRow.implicitWidth
    implicitHeight: 28
    width: implicitWidth
    height: implicitHeight

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: rootMod.now = new Date()
    }

    Row {
        id: clockRow
        anchors.centerIn: parent
        spacing: 8

        UiText {
            anchors.verticalCenter: parent.verticalCenter
            text: rootMod.timeStr
            color: root.ink
            font.family: root.mono
            font.pixelSize: 12
            font.letterSpacing: 1
        }

        UiText {
            anchors.verticalCenter: parent.verticalCenter
            text: rootMod.dateStr
            color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.5)
            font.family: root.mono
            font.pixelSize: 10
            font.letterSpacing: 0.5
        }
    }

    TooltipMixin { id: tip; root: rootMod.root; owner: rootMod; text: rootMod.tooltipText }

    Process {
        id: tzRunner
        command: ["bash", "-c", "omarchy-launch-floating-terminal-with-presentation omarchy-tz-select 2>/dev/null"]
    }

    function openCalendarPanel() {
        tip.hide()
        if (rootMod.barScreen) root.activatePopupScreen(rootMod.barScreen)
        root.openCalendar()
    }

    function toggleClockMode() {
        root.clock12h = !root.clock12h
    }

    HoverHandler {
        id: hover
        cursorShape: Qt.PointingHandCursor
        onHoveredChanged: hovered ? tip.show() : tip.hide()
    }

    TapHandler {
        acceptedButtons: Qt.LeftButton
        gesturePolicy: TapHandler.WithinBounds
        grabPermissions: PointerHandler.CanTakeOverFromAnything
        onTapped: rootMod.openCalendarPanel()
    }

    TapHandler {
        acceptedButtons: Qt.RightButton
        gesturePolicy: TapHandler.WithinBounds
        grabPermissions: PointerHandler.CanTakeOverFromAnything
        onTapped: {
            tip.hide()
            tzRunner.running = false
            tzRunner.running = true
        }
    }

    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        grabPermissions: PointerHandler.CanTakeOverFromAnything
        onWheel: function(event) {
            rootMod.toggleClockMode()
            event.accepted = true
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
    }
}
