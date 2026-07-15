import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../modules"

PanelWindow {
    id: panel
    required property var root
    screen: root.activePopupScreen; color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore; WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-capture"
    WlrLayershell.keyboardFocus: root.captureVisible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    visible: root.captureVisible
    property bool recordingChoices: false
    property var rows: recordingChoices ? [
        {label:"With no audio", detail:"record the selected screen area", icon:"", action:"recording-no-audio"},
        {label:"With desktop audio", detail:"include system audio", icon:"", action:"recording-desktop"},
        {label:"With desktop + microphone", detail:"include system and microphone audio", icon:"", action:"recording-mic"},
        {label:"With desktop + microphone + webcam", detail:"include webcam if available", icon:"", action:"recording-webcam"}
    ] : [
        {label:"Screenshot", detail:"region, window, monitor or desktop", icon:"", action:"screenshot"},
        {label:"Screen recording", detail:"region, monitor or desktop", icon:"", action:"recording"},
        {label:"Text extraction", detail:"select text from the screen", icon:"󰴑", action:"text"},
        {label:"Color picker", detail:"copy a color from the screen", icon:"󰃉", action:"color"}
    ]
    function run(action) {
        if (action === "recording") { recordingChoices = true; list.selectedIndex = 0; return }
        root.captureVisible = false
        proc.command = [Quickshell.env("HOME") + "/.local/bin/qs-capture", action]
        proc.running = false; proc.running = true
    }
    MouseArea { anchors.fill: parent; onClicked: root.captureVisible = false }
    Rectangle {
        id: card
        width: Math.min(440, parent.width - 24)
        height: 270
        x: Math.round((parent.width - width) / 2)
        y: Math.round((parent.height - height) / 2)
        radius: root.pillRadius
        color: root.bg
        border.color: root.pillBorder
        border.width: root.pillBorderW
        PillShadow { theme: root }
        MouseArea { anchors.fill: parent; onClicked: {} }
        Column {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 8
            Text { text: panel.recordingChoices ? "Screen recording" : "Capture"; color: root.ink; font.family: root.mono; font.pixelSize: 13; font.letterSpacing: 2 }
            SelectableList {
                id: list
                width: parent.width
                height: Math.min(260, parent.height - 52)
                model: panel.rows
                selectedIndex: 0
                rowHeight: 42
                textColor: root.ink
                mutedColor: root.seal
                accentColor: root.seal
                selectedColor: root.fillHover
                borderColor: root.seal
                onActivated: function(i) { panel.run(panel.rows[i].action) }
            }
        }
        Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Escape) {
                if (panel.recordingChoices) { panel.recordingChoices = false; list.selectedIndex = 0 }
                else root.captureVisible = false
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) panel.run(panel.rows[list.selectedIndex].action)
        }
    }
    Process { id: proc }
    onVisibleChanged: if (visible) {
        recordingChoices = root.captureAction === "recording"
        root.activateFocusedPopupScreen()
        Qt.callLater(function() { card.forceActiveFocus() })
    }
}
