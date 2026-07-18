import QtQuick
import QtQuick.Controls

Item {
    id: listRoot

    property alias model: view.model
    property alias currentIndex: view.currentIndex
    property int selectedIndex: 0
    property int rowHeight: 34
    property int fontSize: 18
    property int fontWeight: Font.DemiBold
    property string fontFamily: "JetBrainsMono Nerd Font"
    property int rowRadius: 6
    property color textColor: "white"
    property color mutedColor: "gray"
    property color accentColor: "white"
    property color selectedColor: Qt.rgba(1, 1, 1, 0.10)
    property color borderColor: "transparent"
    property string emptyText: "No results"
    property string query: ""
    property bool showScrollBar: false
    property int rowSpacing: 3

    signal activated(int index)
    signal hovered(int index)

    implicitHeight: view.contentHeight

    function select(index) {
        if (view.count <= 0) {
            selectedIndex = 0
            return
        }
        selectedIndex = Math.max(0, Math.min(index, view.count - 1))
        view.currentIndex = selectedIndex
        view.positionViewAtIndex(selectedIndex, ListView.Contain)
    }

    onSelectedIndexChanged: if (view.currentIndex !== selectedIndex) select(selectedIndex)

    ListView {
        id: view
        anchors.fill: parent
        clip: true
        interactive: true
        spacing: listRoot.rowSpacing
        highlightMoveDuration: 0
        currentIndex: 0
        keyNavigationEnabled: false

        ScrollBar.vertical: ScrollBar {
            visible: listRoot.showScrollBar && view.contentHeight > view.height
            policy: ScrollBar.AsNeeded
        }

        delegate: Rectangle {
            required property int index
            required property string label
            property string icon: ""
            property string detail: ""
            property bool enabledRow: true

            width: view.width
            height: listRoot.rowHeight
            radius: listRoot.rowRadius
            color: index === listRoot.selectedIndex ? listRoot.selectedColor : "transparent"
            border.color: index === listRoot.selectedIndex ? listRoot.borderColor : "transparent"
            border.width: index === listRoot.selectedIndex ? 1 : 0
            opacity: enabledRow ? 1 : 0.42

            Row {
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                spacing: 10

                Text {
                    width: 22
                    anchors.verticalCenter: parent.verticalCenter
                    text: icon
                    color: index === listRoot.selectedIndex ? listRoot.accentColor : listRoot.mutedColor
                    font.family: listRoot.fontFamily
                    font.pixelSize: 15
                    horizontalAlignment: Text.AlignHCenter
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 32
                    spacing: 1

                    Text {
                        width: parent.width
                        text: label
                        color: index === listRoot.selectedIndex ? listRoot.textColor : listRoot.mutedColor
                        font.family: listRoot.fontFamily
                        font.pixelSize: listRoot.fontSize
                        font.weight: listRoot.fontWeight
                        elide: Text.ElideRight
                    }

                    Text {
                        width: parent.width
                        visible: detail.length > 0
                        text: detail
                        color: listRoot.mutedColor
                        font.family: listRoot.fontFamily
                        font.pixelSize: 9
                        elide: Text.ElideRight
                    }
                }
            }

            HoverHandler {
                enabled: enabledRow
                cursorShape: Qt.PointingHandCursor
                onHoveredChanged: if (hovered) { listRoot.select(index); listRoot.hovered(index) }
            }
            TapHandler {
                enabled: enabledRow
                acceptedButtons: Qt.LeftButton
                onTapped: listRoot.activated(index)
            }
        }

        Text {
            anchors.centerIn: parent
            visible: view.count === 0
            text: listRoot.emptyText
            color: listRoot.mutedColor
            font.family: listRoot.fontFamily
            font.pixelSize: 11
        }
    }
}
