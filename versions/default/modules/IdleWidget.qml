import QtQuick

Item {
    id: rootMod
    required property var root

    readonly property var idleService: root.idleService
    readonly property bool awake: idleService ? idleService.stayAwake === true : false
    readonly property string tooltipText: awake
        ? "Stay awake: ON · click to allow idle locking"
        : "Stay awake: OFF · click to prevent idle locking"

    visible: awake
    implicitWidth: awake ? 16 : 0
    implicitHeight: 28
    width: implicitWidth
    height: implicitHeight

    Component.onCompleted: root.idleWidgetInstances++
    Component.onDestruction: root.idleWidgetInstances = Math.max(0, root.idleWidgetInstances - 1)

    Text {
        anchors.centerIn: parent
        text: "\uF0F4"
        color: root.seal
        font.family: root.mono
        font.pixelSize: 15
    }

    TooltipMixin { id: tip; root: rootMod.root; owner: rootMod; text: rootMod.tooltipText }

    BarWidgetButton {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onEntered: tip.show()
        onExited: tip.hide()
        onClicked: {
            tip.hide()
            // Same contract as Omarchy's stock StayAwake indicator: the
            // backend is called once, then this widget observes stayAwake.
            if (rootMod.idleService)
                rootMod.idleService.setIdleEnabled(rootMod.awake)
        }
    }
}
