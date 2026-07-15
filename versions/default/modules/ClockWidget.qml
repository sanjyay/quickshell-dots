import QtQuick
import Quickshell
import Quickshell.Io

BarWidgetButton {
    id: rootMod
    required property var root
    property var barScreen: null
    property bool interactive: true
    objectName: "clock-handler"

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
    readonly property bool debugLayout: Quickshell.env("QS_BAR_LAYOUT_DEBUG") === "1"

    visible: root.modClock
    enabled: interactive
    implicitWidth: root.modClock ? Math.round(clockRow.implicitWidth) + 18 : 0
    // The bar's visible clock slot is 32px high. Keeping the interactive item
    // at that same height avoids a dead lower edge when the pill is compact.
    implicitHeight: Math.max(32, root.pillH)
    width: implicitWidth
    opacity: root.modClock ? 1 : 0
    height: implicitHeight
    theme: root
    backgroundVisible: false
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    preventStealing: true
    Accessible.name: "Clock and calendar"
    Accessible.description: tooltipText

    Behavior on implicitWidth { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
    Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

    onEntered: tip.show()
    onExited: tip.hide()
    onClicked: function(mouse) {
        if (mouse.button === Qt.LeftButton) rootMod.openCalendarPanel()
        else if (mouse.button === Qt.RightButton) rootMod.openTimezonePicker()
    }
    onWheel: function(event) {
        rootMod.toggleClockMode()
        event.accepted = true
    }
    onEscapePressed: function(event) {
        if (!root.calendarVisible) return
        rootMod.closeCalendarPanel()
        event.accepted = true
    }

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

    Rectangle {
        visible: rootMod.debugLayout
        anchors.fill: parent
        radius: root.pillRadius
        color: Qt.rgba(0.92, 0.26, 0.24, 0.10)
        border.color: Qt.rgba(0.92, 0.26, 0.24, 0.75)
        border.width: 1
        z: 50
    }

    Rectangle {
        visible: rootMod.debugLayout
        anchors.centerIn: parent
        width: clockRow.implicitWidth
        height: Math.max(clockRow.implicitHeight, 16)
        radius: root.pillRadius
        color: Qt.rgba(0.22, 0.62, 0.90, 0.10)
        border.color: Qt.rgba(0.22, 0.62, 0.90, 0.85)
        border.width: 1
        z: 51
    }

    Process {
        id: tzRunner
        command: ["omarchy-launch-floating-terminal-with-presentation", "omarchy-tz-select"]
    }

    function openCalendarPanel() {
        tip.hide()
        if (rootMod.barScreen) root.activatePopupScreen(rootMod.barScreen)
        root.openCalendar()
    }

    function showTooltip() {
        tip.show()
    }

    function hideTooltip() {
        tip.hide()
    }

    function toggleClockMode() {
        root.clock12h = !root.clock12h
    }

    function openTimezonePicker() {
        tip.hide()
        tzRunner.running = false
        tzRunner.running = true
    }

    function closeCalendarPanel() {
        if (root.calendarVisible) root.calendarVisible = false
    }

}
