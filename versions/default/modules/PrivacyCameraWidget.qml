import QtQuick
import Quickshell
import "../IconMap.js" as IconMap

Item {
    id: rootMod
    required property var root
    required property var cameraSwitch

    readonly property color disabledColor: "#d65d5d"
    readonly property bool hasCameraSwitch: cameraSwitch !== null && cameraSwitch !== undefined
    readonly property bool unavailable: !hasCameraSwitch || !cameraSwitch.opened
    readonly property bool switchOpened: hasCameraSwitch && cameraSwitch.opened
    readonly property bool switchKnown: hasCameraSwitch && cameraSwitch.stateKnown
    readonly property bool switchEnabled: hasCameraSwitch && cameraSwitch.cameraEnabled
    readonly property bool blocked: switchOpened && switchKnown && !switchEnabled
    readonly property bool shown: root.modPrivacy && root.modPrivacyCamera
    readonly property color contentColor: unavailable
        ? Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.45)
        : (!switchKnown ? Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.7)
                               : (switchEnabled ? disabledColor : root.seal))

    Component.onCompleted: console.log("PrivacyCameraWidget completed cameraSwitch=" + (hasCameraSwitch ? cameraSwitch.monitorVersion : "null"))
    onCameraSwitchChanged: console.log("PrivacyCameraWidget cameraSwitch changed cameraSwitch=" + (hasCameraSwitch ? cameraSwitch.monitorVersion : "null"))

    Connections {
        target: rootMod.cameraSwitch
        function onRawEventsChanged() {
            console.log("PrivacyCameraWidget sees rawEvents", rootMod.cameraSwitch.rawEvents)
        }
        function onCameraEnabledChanged() {
            console.log("PrivacyCameraWidget sees cameraEnabled", rootMod.cameraSwitch.cameraEnabled)
        }
    }

    visible: shown
    implicitWidth: shown ? row.implicitWidth + 12 : 0
    implicitHeight: 28
    width: implicitWidth
    height: implicitHeight
    opacity: shown ? 1 : 0

    Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

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
            color: rootMod.contentColor
            font.pixelSize: 13
            Behavior on color { ColorAnimation { duration: 160 } }
        }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
    }
}
