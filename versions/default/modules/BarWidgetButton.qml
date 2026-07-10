import QtQuick

FocusScope {
    id: control
    default property alias contentData: content.data

    property var theme: null
    property bool backgroundVisible: false
    property color backgroundColor: theme ? theme.pill : "transparent"
    property color hoverColor: theme
        ? Qt.rgba(theme.seal.r, theme.seal.g, theme.seal.b, Math.max(theme.pillOpacity, 0.24))
        : backgroundColor
    property color pressedColor: theme
        ? Qt.rgba(theme.seal.r, theme.seal.g, theme.seal.b, Math.max(theme.pillOpacity, 0.32))
        : hoverColor
    property int radius: theme ? theme.pillRadius : 0
    property color borderColor: theme ? theme.pillBorder : "transparent"
    property int borderWidth: theme ? theme.pillBorderW : 0
    property alias acceptedButtons: pointer.acceptedButtons
    property alias hoverEnabled: pointer.hoverEnabled
    property alias cursorShape: pointer.cursorShape
    property alias preventStealing: pointer.preventStealing
    property alias containsMouse: pointer.containsMouse
    property alias pressedButtons: pointer.pressedButtons
    property string traceName: objectName || (parent && parent.objectName ? parent.objectName : "BarWidgetButton")

    signal entered()
    signal exited()
    signal pressed(var event)
    signal released(var event)
    signal canceled()
    signal positionChanged(var event)
    signal clicked(var event)
    signal doubleClicked(var event)
    signal wheel(var event)
    signal escapePressed(var event)

    activeFocusOnTab: enabled && visible
    Accessible.role: Accessible.Button

    Rectangle {
        anchors.fill: parent
        visible: control.backgroundVisible
        radius: control.radius
        color: pointer.pressed ? control.pressedColor
            : pointer.containsMouse ? control.hoverColor
            : control.backgroundColor
        border.color: control.activeFocus ? (control.theme ? control.theme.seal : control.borderColor) : control.borderColor
        border.width: control.activeFocus ? Math.max(1, control.borderWidth) : control.borderWidth
        Behavior on color { ColorAnimation { duration: 120 } }
    }

    Rectangle {
        visible: control.theme && control.theme.pointerTrace
        anchors.fill: parent
        color: "transparent"
        border.color: control.traceName === "clock-handler" ? "#ff3344"
            : control.traceName === "volume-wrapper" ? "#33dd77" : "#3388ff"
        border.width: 1
        z: 100
        Text {
            anchors.top: parent.top
            anchors.left: parent.left
            text: control.traceName
            color: parent.border.color
            font.pixelSize: 8
            z: 1
        }
    }

    // Keep widget content in one explicit layer. The pointer surface is a sibling
    // declared after this layer, matching the reliable event order used by the
    // original volume widget without relying on z-order overrides.
    Item {
        id: content
        anchors.fill: parent
    }

    Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
            control.clicked({ button: Qt.LeftButton, keyboard: true, accepted: true })
            event.accepted = true
        } else if (event.key === Qt.Key_Escape) {
            control.escapePressed(event)
        }
    }

    MouseArea {
        id: pointer
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton
        onEntered: control.entered()
        onExited: control.exited()
        onPressed: function(event) {
            control.forceActiveFocus(Qt.MouseFocusReason)
            if (control.theme && control.theme.tracePointer)
                control.theme.tracePointer(control, control.traceName, event, "pressed")
            control.pressed(event)
        }
        onReleased: function(event) { control.released(event) }
        onCanceled: control.canceled()
        onPositionChanged: function(event) { control.positionChanged(event) }
        onClicked: function(event) {
            if (control.theme && control.theme.tracePointer)
                control.theme.tracePointer(control, control.traceName, event, "clicked")
            control.clicked(event)
        }
        onDoubleClicked: function(event) { control.doubleClicked(event) }
        onWheel: function(event) { control.wheel(event) }
    }
}
