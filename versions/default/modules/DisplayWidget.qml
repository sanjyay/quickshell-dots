import QtQuick

Item {
    id: widget
    required property var root
    required property var barScreen

    visible: implicitWidth > 0.5
    implicitWidth: root.modDisplay ? 24 : 0
    implicitHeight: 28
    width: implicitWidth
    height: implicitHeight

    UiText {
        anchors.centerIn: parent
        text: String.fromCodePoint(0xF0379)
        renderType: Text.QtRendering
        color: root.seal
        font.family: root.mono
        font.pixelSize: 15
        Behavior on color { ColorAnimation { duration: 120 } }
    }

    TooltipMixin {
        id: tooltip
        root: widget.root
        owner: widget
        text: "Display"
    }

    BarWidgetButton {
        objectName: "display-handler"
        anchors.fill: parent
        theme: widget.root
        hoverEnabled: true
        onEntered: tooltip.show()
        onExited: tooltip.hide()
        onClicked: function(event) {
            tooltip.hide()
            var sameOutput = widget.root.display.outputName === widget.barScreen.name
            if (widget.root.displayVisible && sameOutput) {
                widget.root.displayVisible = false
                return
            }
            widget.root.activatePopupScreen(widget.barScreen)
            widget.root.display.outputName = widget.barScreen.name
            widget.root.setPanelAnchor("display", widget.mapToItem(null, widget.width / 2, 0).x,
                widget.barScreen.name)
            widget.root.displayVisible = true
        }
    }
}
