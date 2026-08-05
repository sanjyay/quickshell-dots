import QtQuick
import Quickshell
import Quickshell.Wayland
import "../modules"
import "../services/DisplayModel.js" as DisplayModel

PopupSurface {
    id: panel

    opened: root.displayVisible
    layerNamespace: "quickshell-astra-display"

    readonly property var service: root.display
    readonly property int baseText: root.uiTextSize
    readonly property int gap: 8

    MouseArea {
        anchors.fill: parent
        enabled: panel.opened
        onClicked: panel.root.displayVisible = false
    }

    Rectangle {
        id: card
        width: Math.min(parent.width - 12, Math.max(330, panel.baseText * 20))
        height: content.implicitHeight + 28
        x: Math.round(Math.max(6, Math.min(panel.root.displayBarX - width / 2, parent.width - width - 6)))
        y: panel.root.barPosition === "bottom"
            ? parent.height - panel.root.barReservedExtent - panel.gap - height
            : panel.root.barReservedExtent + panel.gap
        radius: panel.reveal > 0.001 ? panel.root.pillRadius : 0
        color: panel.root.bg
        border.color: panel.root.pillBorder
        border.width: Math.max(1, panel.root.pillBorderW)
        opacity: panel.reveal
        focus: panel.opened
        activeFocusOnTab: panel.opened

        PillShadow { theme: panel.root }
        MouseArea { anchors.fill: parent; onClicked: {} }

        Keys.onEscapePressed: function(event) {
            panel.root.displayVisible = false
            event.accepted = true
        }

        Column {
            id: content
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 14
            spacing: 11

            Row {
                width: parent.width
                spacing: 11

                UiText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: String.fromCodePoint(0xF0379)
                    renderType: Text.QtRendering
                    color: panel.root.seal
                    font.family: panel.root.mono
                    font.pixelSize: 22
                }
                Column {
                    width: parent.width - 34
                    spacing: 1
                    UiText {
                        text: "Display"
                        color: panel.root.ink
                        font.family: panel.root.mono
                        font.pixelSize: panel.baseText + 2
                        font.weight: Font.DemiBold
                    }
                    UiText {
                        width: parent.width
                        text: panel.service.monitor
                            ? (panel.service.monitor.description || panel.service.monitor.name)
                            : (panel.service.monitorError || "Display unavailable")
                        color: panel.root.sumiHi
                        font.family: panel.root.mono
                        font.pixelSize: Math.max(10, panel.baseText - 2)
                        elide: Text.ElideRight
                    }
                }
            }

            Rectangle { width: parent.width; height: 1; color: panel.root.sep }

            SectionHeader {
                width: parent.width
                label: "BRIGHTNESS"
                value: panel.service.brightnessAvailable
                    ? panel.service.brightnessPercent + "%" : "Unavailable"
            }
            AstraSlider {
                id: brightnessSlider
                width: parent.width
                enabled: panel.service.brightnessAvailable
                from: 1
                to: 100
                stepSize: 1
                value: panel.service.brightnessPercent
                markerCount: 0
                accessibleName: "Display brightness"
                onPreviewed: function(next) { panel.service.previewBrightness(next) }
                onCommitted: function(next) { panel.service.applyBrightness(next) }
            }

            Rectangle { width: parent.width; height: 1; color: panel.root.sep }

            SectionHeader {
                width: parent.width
                label: "SYSTEM TEXT SIZE"
                value: panel.service.textSize + "px"
            }
            AstraSlider {
                id: textSlider
                width: parent.width
                from: 0
                to: panel.service.textSizeSteps.length - 1
                stepSize: 1
                markerCount: panel.service.textSizeSteps.length
                value: Math.max(0, panel.service.textSizeSteps.indexOf(panel.service.textSize))
                accessibleName: "System and Astra text size"
                onPreviewed: function(next) {
                    panel.service.setTextSize(panel.service.textSizeSteps[Math.round(next)])
                }
                onCommitted: function(next) {
                    panel.service.setTextSize(panel.service.textSizeSteps[Math.round(next)])
                }
            }

            Rectangle { width: parent.width; height: 1; color: panel.root.sep }

            SectionHeader {
                width: parent.width
                label: "SCALE"
                value: panel.service.monitor ? panel.service.monitor.scale + "x" : "Unavailable"
            }
            Row {
                width: parent.width
                height: Math.max(32, panel.baseText + 18)
                spacing: 4

                Repeater {
                    model: panel.service.scalePresets
                    delegate: BarWidgetButton {
                        id: scaleButton
                        required property string modelData
                        required property int index
                        width: (parent.width - parent.spacing * (panel.service.scalePresets.length - 1))
                            / panel.service.scalePresets.length
                        height: parent.height
                        enabled: panel.service.monitor !== null && !panel.service.scaleApplying
                        theme: panel.root
                        backgroundVisible: true
                        backgroundColor: active ? panel.root.fillActive : panel.root.fillIdle
                        borderColor: active ? panel.root.seal : panel.root.sep
                        Accessible.name: "Set display scale to " + modelData + "x"
                        readonly property bool active: panel.service.monitor
                            && DisplayModel.scaleIndex(panel.service.scalePresets,
                                panel.service.monitor.scale) === index
                        onClicked: panel.service.applyScale(modelData)
                        UiText {
                            anchors.centerIn: parent
                            text: scaleButton.modelData + "x"
                            color: scaleButton.active ? panel.root.seal : panel.root.ink
                            font.family: panel.root.mono
                            font.pixelSize: Math.max(10, panel.baseText - 1)
                            font.weight: scaleButton.active ? Font.DemiBold : Font.Normal
                        }
                    }
                }
            }

            UiText {
                width: parent.width
                visible: panel.service.textSizeApplying || panel.service.scaleApplying || panel.service.scaleError !== ""
                    || panel.service.settingsError !== ""
                text: panel.service.textSizeApplying ? "Applying system text size…"
                    : panel.service.scaleApplying ? "Applying scale…"
                    : (panel.service.scaleError || panel.service.settingsError)
                color: panel.service.scaleError ? panel.root.warn : panel.root.sumiHi
                font.family: panel.root.mono
                font.pixelSize: Math.max(10, panel.baseText - 2)
                wrapMode: Text.Wrap
            }
        }
    }

    component SectionHeader: Item {
        required property string label
        required property string value
        implicitHeight: Math.max(leftLabel.implicitHeight, rightValue.implicitHeight)
        UiText {
            id: leftLabel
            anchors.left: parent.left
            text: parent.label
            color: panel.root.sumiHi
            font.family: panel.root.mono
            font.pixelSize: Math.max(10, panel.baseText - 2)
            font.letterSpacing: 1
            font.weight: Font.Medium
        }
        UiText {
            id: rightValue
            anchors.right: parent.right
            text: parent.value
            color: panel.root.ink
            font.family: panel.root.mono
            font.pixelSize: Math.max(10, panel.baseText - 1)
            font.weight: Font.Medium
        }
    }

    component AstraSlider: FocusScope {
        id: slider
        property real from: 0
        property real to: 100
        property real stepSize: 1
        property real value: from
        property int markerCount: 0
        property string accessibleName: "Slider"
        signal previewed(real value)
        signal committed(real value)

        implicitHeight: 24
        activeFocusOnTab: enabled
        Accessible.role: Accessible.Slider
        Accessible.name: accessibleName

        function clamp(next) { return Math.max(from, Math.min(to, next)) }
        function snapped(next) {
            return clamp(from + Math.round((next - from) / stepSize) * stepSize)
        }
        function fromX(x) {
            var boundedX = Math.max(0, Math.min(track.width, x))
            return snapped(from + boundedX / Math.max(1, track.width) * (to - from))
        }
        function adjust(direction) {
            var next = snapped(value + direction * stepSize)
            previewed(next)
            committed(next)
        }

        Keys.onLeftPressed: function(event) { adjust(-1); event.accepted = true }
        Keys.onRightPressed: function(event) { adjust(1); event.accepted = true }
        Keys.onDownPressed: function(event) { adjust(-1); event.accepted = true }
        Keys.onUpPressed: function(event) { adjust(1); event.accepted = true }

        Rectangle {
            id: track
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            height: 6
            radius: 3
            color: panel.root.fillActive
            opacity: slider.enabled ? 1 : 0.45

            Rectangle {
                width: parent.width * ((slider.value - slider.from) / Math.max(1, slider.to - slider.from))
                height: parent.height
                radius: parent.radius
                color: panel.root.seal
            }

            Repeater {
                model: slider.markerCount
                Rectangle {
                    required property int index
                    visible: slider.markerCount > 1
                    width: 2
                    height: 10
                    radius: 1
                    x: index * (track.width - width) / Math.max(1, slider.markerCount - 1)
                    anchors.verticalCenter: parent.verticalCenter
                    color: panel.root.ink
                    opacity: 0.42
                }
            }

            Rectangle {
                width: slider.activeFocus ? 14 : 12
                height: width
                radius: width / 2
                x: Math.max(0, Math.min(parent.width - width,
                    parent.width * ((slider.value - slider.from) / Math.max(1, slider.to - slider.from)) - width / 2))
                anchors.verticalCenter: parent.verticalCenter
                color: panel.root.seal
                border.color: slider.activeFocus ? panel.root.ink : panel.root.pillBorder
                border.width: 1
            }

            MouseArea {
                anchors.fill: parent
                anchors.topMargin: -9
                anchors.bottomMargin: -9
                enabled: slider.enabled
                cursorShape: Qt.PointingHandCursor
                preventStealing: true
                onPressed: function(mouse) {
                    slider.forceActiveFocus(Qt.MouseFocusReason)
                    slider.previewed(slider.fromX(mouse.x))
                }
                onPositionChanged: function(mouse) {
                    if (pressed) slider.previewed(slider.fromX(mouse.x))
                }
                onReleased: function(mouse) { slider.committed(slider.fromX(mouse.x)) }
            }
        }
    }
}
