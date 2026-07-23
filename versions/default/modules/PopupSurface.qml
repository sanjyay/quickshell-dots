import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: surface

    required property var root
    required property bool opened
    required property string layerNamespace

    property int openDuration: 160
    property int closeDuration: 120
    property real reveal: opened ? 1 : 0

    screen: root.activePopupScreen
    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: layerNamespace

    Behavior on reveal {
        NumberAnimation {
            duration: surface.opened ? surface.openDuration : surface.closeDuration
            easing.type: surface.opened ? Easing.OutCubic : Easing.InCubic
        }
    }

    visible: reveal > 0.001
    WlrLayershell.keyboardFocus: opened ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
}
