import QtQuick
import Quickshell
import Quickshell.Wayland
import "modules"
import "IconMap.js" as IconMap

PanelWindow {
    id: overlay
    required property var root
    required property var targetScreen
    readonly property real brightnessScale: 1.5
    readonly property real brightnessWidth: 72 * brightnessScale
    readonly property real brightnessHeight: 64 * brightnessScale
    readonly property real usableHeight: Math.max(1, targetScreen.height - root.barReservedExtent)
    readonly property real placementRatio: 0.70
    readonly property real desiredOsdY: (root.barPosition === "top" ? root.barReservedExtent : 0)
        + usableHeight * placementRatio
    readonly property real minimumOsdY: root.barPosition === "top"
        ? root.barReservedExtent + 72
        : 72
    readonly property real maximumOsdY: targetScreen.height
        - (root.barPosition === "bottom" ? root.barReservedExtent : 0)
        - 60 - 56
    readonly property real osdY: Math.max(minimumOsdY, Math.min(maximumOsdY, desiredOsdY))
    screen: targetScreen
    color: "transparent"
    anchors { top: true; left: true; right: true }
    implicitHeight: Math.ceil(osdY + (root.osdKind === "brightness" ? brightnessHeight + 12 : 72))
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.namespace: "quickshell-hardware-osd"
    mask: Region {}
    visible: true

    Rectangle {
        id: card
        readonly property bool active: root.osdVisible && root.osdScreenName === targetScreen.name
        readonly property bool percentageEvent: root.osdValue !== "" && !isNaN(Number(root.osdValue))
        readonly property real percentage: percentageEvent ? Math.max(0, Math.min(100, Number(root.osdValue))) : 0
        readonly property bool volumeEvent: root.osdKind === "volume"
        readonly property bool brightnessEvent: root.osdKind === "brightness"
        readonly property bool cameraEvent: root.osdKind === "camera"
        readonly property bool cameraEnabled: cameraEvent
            && (root.osdDetail.toLowerCase().indexOf("enabled") >= 0
                || ["on", "true"].indexOf(root.osdDetail.toLowerCase()) >= 0)
        readonly property bool muted: (volumeEvent || root.osdKind === "microphone") && root.osdDetail === "true"
        readonly property string semanticIcon: {
            if (root.osdIcon) return root.osdIcon
            if (volumeEvent) {
                if (muted || percentage <= 0) return "󰖁"
                if (percentage < 35) return "󰕿"
                if (percentage < 70) return "󰖀"
                return "󰕾"
            }
            if (root.osdKind === "microphone") return muted ? "󰍭" : "󰍬"
            if (root.osdKind === "brightness") return "󰃠"
            if (root.osdKind === "keyboard") return "󰌌"
            return root.osdKind
        }

        visible: opacity > 0.001
        opacity: active ? 1 : 0
        scale: active ? 1 : 0.965
        width: card.brightnessEvent ? overlay.brightnessWidth
            : (card.cameraEvent ? 60 : Math.min(300, Math.max(190, row.implicitWidth + 30)))
        height: card.brightnessEvent ? overlay.brightnessHeight : 60
        x: Math.round((parent.width - width) / 2)
        y: overlay.osdY + (active ? 0 : -3)
        radius: card.brightnessEvent ? 0 : root.pillRadius
        color: card.brightnessEvent ? "transparent" : root.paper
        border.color: card.brightnessEvent ? "transparent" : root.pillBorder
        border.width: card.brightnessEvent ? 0 : root.pillBorderW
        PillShadow { theme: root; visible: !card.brightnessEvent }

        Behavior on opacity { NumberAnimation { duration: card.active ? 140 : 180; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
        Behavior on y { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

        Row {
            id: row; anchors.centerIn: parent; spacing: 10
            UiText {
                id: osdIcon
                anchors.verticalCenter: parent.verticalCenter
                visible: !card.brightnessEvent && !card.cameraEvent
                text: card.semanticIcon
                color: card.muted ? root.sumi : root.seal
                font.family: root.mono; font.pixelSize: 18
                transformOrigin: Item.Center
            }
            IconText {
                id: cameraIcon
                anchors.verticalCenter: parent.verticalCenter
                visible: card.cameraEvent
                text: IconMap.icon(card.cameraEnabled ? "videocam" : "videocam_off")
                color: card.cameraEnabled ? root.seal : root.sumi
                font.pixelSize: 27
                transformOrigin: Item.Center
                Behavior on color { ColorAnimation { duration: 150 } }
            }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                visible: !card.cameraEvent
                spacing: 5
                UiText {
                    visible: !card.percentageEvent
                    text: root.osdDetail || root.osdKind
                    color: root.ink; font.family: root.mono; font.pixelSize: 11
                }
                Item {
                    id: meter
                    visible: card.percentageEvent && !card.brightnessEvent
                    readonly property int segmentCount: 14
                    width: 160; height: 10

                    Row {
                        anchors.centerIn: parent
                        spacing: 3
                        Repeater {
                            model: meter.segmentCount
                            delegate: Item {
                                id: segmentCell
                                required property int index
                                readonly property bool lit: !card.muted
                                    && card.percentage >= ((index + 1) * 100 / meter.segmentCount)
                                readonly property bool leadingEdge: lit
                                    && card.percentage < ((index + 2) * 100 / meter.segmentCount)
                                width: 8; height: 10

                                Rectangle {
                                    anchors.centerIn: parent
                                    width: 8; height: segmentCell.lit ? 8 : 6
                                    radius: 2
                                    color: segmentCell.lit
                                        ? root.seal
                                        : Qt.rgba(root.sep.r, root.sep.g, root.sep.b, card.muted ? 0.30 : 0.58)
                                    opacity: segmentCell.lit ? 1 : 0.72
                                    Behavior on height { NumberAnimation { duration: 130; easing.type: Easing.OutCubic } }
                                    Behavior on color { ColorAnimation { duration: 145 } }
                                    Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                                }

                                Rectangle {
                                    visible: segmentCell.leadingEdge
                                    z: -1
                                    anchors.centerIn: parent
                                    width: 14; height: 14; radius: 5
                                    color: Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.16)
                                    opacity: segmentCell.leadingEdge ? 1 : 0
                                    Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                                }
                            }
                        }
                    }
                }

                Item {
                    id: brightnessBurst
                    visible: card.brightnessEvent && card.percentageEvent
                    readonly property int rayCount: 16
                    width: overlay.brightnessWidth; height: overlay.brightnessHeight

                    Repeater {
                        model: brightnessBurst.rayCount
                        delegate: Item {
                            id: rayFrame
                            required property int index
                            readonly property bool lit: card.percentage
                                >= ((index + 1) * 100 / brightnessBurst.rayCount)
                            readonly property bool leadingRay: lit && card.percentage
                                < ((index + 2) * 100 / brightnessBurst.rayCount)
                            anchors.fill: parent
                            rotation: index * (360 / brightnessBurst.rayCount)

                            Rectangle {
                                anchors.horizontalCenter: parent.horizontalCenter
                                y: rayFrame.lit
                                    ? 3 * overlay.brightnessScale
                                    : 6 * overlay.brightnessScale
                                width: 2.5 * overlay.brightnessScale
                                height: rayFrame.lit
                                    ? 10 * overlay.brightnessScale
                                    : 7 * overlay.brightnessScale
                                radius: width / 2
                                color: rayFrame.lit
                                    ? root.seal
                                    : Qt.rgba(root.sep.r, root.sep.g, root.sep.b, 0.52)
                                opacity: rayFrame.lit ? 1 : 0.66
                                Behavior on y { NumberAnimation { duration: 145; easing.type: Easing.OutCubic } }
                                Behavior on height { NumberAnimation { duration: 145; easing.type: Easing.OutCubic } }
                                Behavior on color { ColorAnimation { duration: 155 } }
                                Behavior on opacity { NumberAnimation { duration: 130; easing.type: Easing.OutCubic } }
                            }

                            Rectangle {
                                visible: rayFrame.leadingRay
                                anchors.horizontalCenter: parent.horizontalCenter
                                y: 0
                                width: 9 * overlay.brightnessScale
                                height: 14 * overlay.brightnessScale
                                radius: 5 * overlay.brightnessScale
                                color: Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.14)
                            }
                        }
                    }

                    Rectangle {
                        id: burstCore
                        anchors.centerIn: parent
                        width: 30 * overlay.brightnessScale
                        height: 30 * overlay.brightnessScale
                        radius: 15 * overlay.brightnessScale
                        color: Qt.rgba(root.paper.r, root.paper.g, root.paper.b, 0.72)
                        border.color: root.seal
                        border.width: 1
                        Behavior on color { ColorAnimation { duration: 160 } }
                    }

                    Rectangle {
                        anchors.centerIn: burstCore
                        width: 23 * overlay.brightnessScale
                        height: 23 * overlay.brightnessScale
                        radius: 11.5 * overlay.brightnessScale
                        color: Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.11)
                    }

                    UiText {
                        id: brightnessValue
                        anchors.centerIn: burstCore
                        anchors.verticalCenterOffset: -1
                        width: 34 * overlay.brightnessScale
                        height: 18 * overlay.brightnessScale
                        text: Math.round(card.percentage)
                        color: root.ink
                        font.family: root.mono
                        font.pixelSize: 12 * overlay.brightnessScale
                        font.weight: Font.DemiBold
                        font.letterSpacing: 0
                        font.features: ({ "tnum": 1 })
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        transformOrigin: Item.Center
                    }
                }
            }
            UiText {
                id: valueText
                anchors.verticalCenter: parent.verticalCenter
                visible: root.osdValue !== "" && !card.brightnessEvent && !card.cameraEvent
                text: card.percentageEvent ? Math.round(card.percentage) + "%" : root.osdValue
                color: card.muted ? root.sumi : root.ink
                font.family: root.mono; font.pixelSize: 12; font.weight: Font.Medium
                transformOrigin: Item.Center
            }
        }

        Connections {
            target: root
            function onOsdSerialChanged() {
                if (!card.active) return
                response.restart()
            }
        }
        SequentialAnimation {
            id: response
            ParallelAnimation {
                NumberAnimation { target: osdIcon; property: "scale"; to: 1.08; duration: 75; easing.type: Easing.OutCubic }
                NumberAnimation { target: cameraIcon; property: "scale"; to: 1.10; duration: 75; easing.type: Easing.OutCubic }
                NumberAnimation { target: valueText; property: "scale"; to: 1.045; duration: 75; easing.type: Easing.OutCubic }
                NumberAnimation { target: brightnessValue; property: "scale"; to: 1.045; duration: 75; easing.type: Easing.OutCubic }
            }
            ParallelAnimation {
                NumberAnimation { target: osdIcon; property: "scale"; to: 1; duration: 130; easing.type: Easing.OutCubic }
                NumberAnimation { target: cameraIcon; property: "scale"; to: 1; duration: 130; easing.type: Easing.OutCubic }
                NumberAnimation { target: valueText; property: "scale"; to: 1; duration: 130; easing.type: Easing.OutCubic }
                NumberAnimation { target: brightnessValue; property: "scale"; to: 1; duration: 130; easing.type: Easing.OutCubic }
            }
        }
    }
}
