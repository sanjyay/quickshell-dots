import QtQuick
import Quickshell
import Quickshell.Wayland
import "modules"

PanelWindow {
    id: overlay
    required property var root
    required property var manager
    required property var targetScreen
    screen: targetScreen
    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.namespace: "quickshell-notifications"
    mask: Region { item: cards }

    Column {
        id: cards
        width: 380
        spacing: 8
        x: parent.width - width - 12
        y: root.barPosition === "top" ? root.barReservedExtent + 12 : 12

        Repeater {
            model: manager.visibleFor(targetScreen.name)
            delegate: Rectangle {
                id: toastCard
                required property var modelData
                property var entry: modelData
                readonly property bool showAppName: String(modelData.appName || "").trim().toLowerCase() !== "notify-send"
                width: cards.width
                height: content.implicitHeight + 24
                radius: root.pillRadius
                color: root.paper
                border.color: root.pillBorder
                border.width: root.pillBorderW
                PillShadow { theme: root }

                MouseArea { anchors.fill: parent; onClicked: manager.invoke(modelData, "") }
                Column {
                    id: content
                    anchors { left: parent.left; right: parent.right; top: parent.top }
                    anchors.margins: 12; anchors.rightMargin: 34
                    spacing: 4
                    Image { width: parent.width; height: modelData.image ? 120 : 0; visible: height > 0; source: modelData.image || ""; fillMode: Image.PreserveAspectFit; asynchronous: true }
                    UiText { visible: toastCard.showAppName; width: parent.width; text: modelData.appName; color: root.sumiHi; font.family: root.mono; font.pixelSize: 10; elide: Text.ElideRight }
                    UiText { width: parent.width; text: modelData.summary; color: root.ink; font.family: root.mono; font.pixelSize: 13; font.weight: Font.Medium; wrapMode: Text.WordWrap; visible: text !== "" }
                    UiText { width: parent.width; text: modelData.body; color: root.sumi; font.family: root.mono; font.pixelSize: 11; wrapMode: Text.WordWrap; maximumLineCount: 4; elide: Text.ElideRight; visible: text !== "" }
                    Row {
                        spacing: 6
                        Repeater {
                            model: modelData.notification ? modelData.notification.actions : (modelData.actions || [])
                            delegate: Rectangle {
                                required property var modelData
                                visible: modelData.identifier !== "default"
                                width: actionText.implicitWidth + 14; height: 24; radius: root.tileRadius
                                color: actionMouse.containsMouse ? root.fillHover : root.fillIdle
                                border.color: root.sep; border.width: 1
                                UiText { id: actionText; anchors.centerIn: parent; text: modelData.text; color: root.ink; font.family: root.mono; font.pixelSize: 10 }
                                MouseArea { id: actionMouse; anchors.fill: parent; hoverEnabled: true; onClicked: manager.invoke(toastCard.entry, modelData.identifier) }
                            }
                        }
                    }
                }
                Rectangle {
                    anchors { top: parent.top; right: parent.right; margins: 8 }
                    width: 20; height: 20; radius: 10; color: closeMouse.containsMouse ? root.fillHover : "transparent"
                    UiText { anchors.centerIn: parent; text: "✕"; color: root.sumi; font.pixelSize: 10 }
                    MouseArea { id: closeMouse; anchors.fill: parent; hoverEnabled: true; onClicked: manager.close(modelData.key, true) }
                }
            }
        }
    }
}
