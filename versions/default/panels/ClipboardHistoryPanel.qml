import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../modules"

PanelWindow {
    id: panel
    required property var root

    screen: root.activePopupScreen
    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-clipboard"
    WlrLayershell.keyboardFocus: root.clipboardVisible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    visible: root.clipboardVisible

    property var items: []
    property int selectedIndex: 0
    property string query: ""
    property string statusText: ""
    property bool syncingList: false
    readonly property bool inputDebug: Quickshell.env("QS_CLIPBOARD_INPUT_DEBUG") === "1"
    readonly property var visibleItems: filteredItems()
    readonly property var selectedItem: visibleItems.length > 0
        ? visibleItems[Math.max(0, Math.min(selectedIndex, visibleItems.length - 1))] : null

    function inputDebugLog(message) {
        if (inputDebug) console.log("Clipboard input: " + message)
    }

    function filteredItems() {
        var needle = query.trim().toLowerCase()
        if (!needle) return items
        return items.filter(function(item) {
            return (item.label + " " + item.detail + " " + item.previewText).toLowerCase().indexOf(needle) >= 0
        })
    }

    function setSelection(index) {
        var count = visibleItems.length
        var next = count > 0 ? Math.max(0, Math.min(index, count - 1)) : 0
        selectedIndex = next
        if (!leftList) return
        syncingList = true
        leftList.currentIndex = next
        leftList.positionViewAtIndex(next, ListView.Contain)
        syncingList = false
    }

    function resetSelection() {
        Qt.callLater(function() { panel.setSelection(0) })
    }

    function refresh() {
        queryProc.running = false
        queryProc.running = true
    }

    function imageSource(item) {
        if (!item || item.kind !== "image" || !item.imagePath) return ""
        if (item.imagePath.indexOf("file://") === 0) return item.imagePath
        return "file://" + item.imagePath
    }

    function activate(index) {
        setSelection(index)
        var row = selectedItem
        if (!row) return
        copyProc.command = [Quickshell.env("HOME") + "/.local/bin/qs-clipboard", "copy", row.id]
        copyProc.running = false
        copyProc.running = true
        root.clipboardVisible = false
    }

    function remove(index) {
        setSelection(index)
        var row = selectedItem
        if (!row) return
        removeProc.command = [Quickshell.env("HOME") + "/.local/bin/qs-clipboard", "delete", row.id]
        removeProc.running = false
        removeProc.running = true
        statusText = "Removing clipboard entry…"
        refreshTimer.restart()
    }

    function parse(text) {
        try {
            var raw = []
            var lines = String(text || "").trim().split("\n")
            for (var lineIndex = 0; lineIndex < lines.length; lineIndex++) {
                if (!lines[lineIndex].trim()) continue
                var response = JSON.parse(lines[lineIndex])
                if (response.item) raw.push(response.item)
                else if (response.items) raw = raw.concat(response.items)
            }

            var out = []
            for (var i = 0; i < raw.length; i++) {
                var x = raw[i] || {}
                var type = String(x.preview_type || (x.text ? "text" : "other")).toLowerCase()
                var isImage = type === "file" && String(x.preview || "").length > 0
                var fullText = String(x.text || "")
                var imagePath = isImage ? String(x.preview) : ""
                var label = isImage
                    ? "Image clipboard entry"
                    : (fullText ? fullText.replace(/\s+/g, " ").trim().slice(0, 100) : "Clipboard entry")
                var detail = String(x.subtext || x.provider || "clipboard")
                if (x.mime || x.mime_type) detail += " · " + String(x.mime || x.mime_type)
                out.push({
                    id: String(x.identifier || ""),
                    kind: isImage ? "image" : (fullText ? "text" : "other"),
                    label: label,
                    detail: detail,
                    fullText: fullText,
                    previewText: String(x.preview || fullText || ""),
                    imagePath: imagePath,
                    mimeType: String(x.mime || x.mime_type || ""),
                    subtext: String(x.subtext || ""),
                    icon: isImage ? "" : (fullText ? "" : "󰋼")
                })
            }
            items = out.filter(function(item) { return item.id.length > 0 })
            statusText = ""
            resetSelection()
        } catch (e) {
            statusText = "Clipboard history unavailable"
            items = []
            resetSelection()
        }
    }

    function handleKey(event) {
        var count = visibleItems.length
        var before = selectedIndex
        var branch = "unhandled"
        if (event.key === Qt.Key_Escape) {
            branch = "close"
            root.clipboardVisible = false
            event.accepted = true
        } else if (event.key === Qt.Key_Down) {
            branch = "moveNext"
            if (count > 0) setSelection((selectedIndex + 1) % count)
            event.accepted = true
        } else if (event.key === Qt.Key_Up) {
            branch = "movePrevious"
            if (count > 0) setSelection((selectedIndex - 1 + count) % count)
            event.accepted = true
        } else if (event.key === Qt.Key_PageDown) {
            branch = "pageDown"
            if (count > 0) setSelection(Math.min(count - 1, selectedIndex + 5))
            event.accepted = true
        } else if (event.key === Qt.Key_PageUp) {
            branch = "pageUp"
            if (count > 0) setSelection(Math.max(0, selectedIndex - 5))
            event.accepted = true
        } else if (event.key === Qt.Key_Home && searchField.text.length === 0) {
            branch = "home"
            if (count > 0) setSelection(0)
            event.accepted = true
        } else if (event.key === Qt.Key_End && searchField.text.length === 0) {
            branch = "end"
            if (count > 0) setSelection(count - 1)
            event.accepted = true
        } else if (event.key === Qt.Key_Delete && searchField.text.length === 0) {
            branch = "remove"
            remove(selectedIndex)
            event.accepted = true
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            branch = "copy"
            activate(selectedIndex)
            event.accepted = true
        }
        inputDebugLog("key=" + event.key + " text=" + event.text +
            " modifiers=" + event.modifiers + " autoRepeat=" + event.isAutoRepeat +
            " before=" + before + " count=" + count + " branch=" + branch +
            " after=" + selectedIndex + " accepted=" + event.accepted)
    }

    Timer {
        id: focusTimer
        interval: 40
        repeat: false
        onTriggered: if (root.clipboardVisible && panel.visible) searchField.forceActiveFocus()
    }

    MouseArea {
        anchors.fill: parent
        enabled: root.clipboardVisible
        onClicked: root.clipboardVisible = false
    }

    Rectangle {
        id: card
        width: Math.min(760, parent.width - 24)
        height: Math.min(parent.height - 48, 540)
        x: Math.round((parent.width - width) / 2)
        y: Math.round((parent.height - height) / 2)
        radius: root.pillRadius
        color: root.bg
        border.color: root.pillBorder
        border.width: root.pillBorderW
        clip: true
        PillShadow { theme: root }
        MouseArea { anchors.fill: parent; onClicked: {} }

        Column {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 8

            Text {
                width: parent.width
                height: 20
                text: "Clipboard history"
                color: root.ink
                font.family: root.mono
                font.pixelSize: 13
                font.letterSpacing: 2
            }

            Item {
                id: body
                width: parent.width
                height: parent.height - 20 - 18 - (statusText.length > 0 ? 14 : 0) - 24

                Item {
                    id: leftPane
                    property bool stacked: body.width < 620
                    x: 0
                    y: 0
                    width: stacked ? body.width : Math.round(body.width * 0.39)
                    height: stacked ? Math.round(body.height * 0.46) : body.height

                    Rectangle {
                        id: searchBox
                        width: parent.width
                        height: 34
                        radius: root.tileRadius
                        color: root.fillIdle
                        border.color: searchField.activeFocus ? root.seal : root.sep
                        border.width: 1

                        TextInput {
                            id: searchField
                            anchors.left: parent.left
                            anchors.leftMargin: 12
                            anchors.right: parent.right
                            anchors.rightMargin: 12
                            anchors.verticalCenter: parent.verticalCenter
                            text: panel.query
                            color: root.ink
                            selectionColor: root.fillHover
                            selectedTextColor: root.ink
                            font.family: root.mono
                            font.pixelSize: 11
                            clip: true
                            Keys.priority: Keys.BeforeItem
                            onTextChanged: {
                                if (panel.query !== text) panel.query = text
                                panel.resetSelection()
                            }
                            Keys.onPressed: function(event) { panel.handleKey(event) }
                        }

                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: 12
                            anchors.verticalCenter: parent.verticalCenter
                            visible: searchField.text.length === 0 && !searchField.activeFocus
                            text: "Search clipboard…"
                            color: root.sumi
                            font.family: root.mono
                            font.pixelSize: 11
                        }
                    }

                    ListView {
                        id: leftList
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: searchBox.bottom
                        anchors.bottom: parent.bottom
                        anchors.topMargin: 8
                        clip: true
                        interactive: true
                        spacing: 3
                        model: panel.visibleItems
                        currentIndex: 0
                        keyNavigationEnabled: false
                        onCurrentIndexChanged: {
                            if (!panel.syncingList && currentIndex >= 0 && currentIndex < panel.visibleItems.length)
                                panel.setSelection(currentIndex)
                        }

                        ScrollBar.vertical: ScrollBar {
                            policy: ScrollBar.AsNeeded
                            width: 6
                            contentItem: Rectangle { radius: 3; color: root.seal; opacity: 0.65 }
                            background: Rectangle { radius: 3; color: root.fillIdle; opacity: 0.35 }
                        }

                        delegate: Item {
                            required property int index
                            required property var modelData
                            width: leftList.width
                            height: 46

                            Rectangle {
                                anchors.fill: parent
                                anchors.leftMargin: 2
                                anchors.rightMargin: 2
                                radius: 6
                                color: panel.selectedIndex === index ? root.fillHover : "transparent"
                                border.color: panel.selectedIndex === index ? root.seal : "transparent"
                                border.width: panel.selectedIndex === index ? 1 : 0
                            }

                            Text {
                                anchors.left: parent.left
                                anchors.leftMargin: 10
                                anchors.verticalCenter: parent.verticalCenter
                                width: 22
                                text: modelData.icon
                                color: panel.selectedIndex === index ? root.seal : root.sumi
                                font.family: root.mono
                                font.pixelSize: 14
                                horizontalAlignment: Text.AlignHCenter
                            }

                            Column {
                                anchors.left: parent.left
                                anchors.leftMargin: 42
                                anchors.right: parent.right
                                anchors.rightMargin: 10
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 1
                                Text {
                                    width: parent.width
                                    text: modelData.label
                                    color: panel.selectedIndex === index ? root.ink : root.seal
                                    font.family: root.mono
                                    font.pixelSize: 11
                                    elide: Text.ElideRight
                                }
                                Text {
                                    width: parent.width
                                    text: modelData.detail
                                    color: root.sumi
                                    font.family: root.mono
                                    font.pixelSize: 8
                                    elide: Text.ElideRight
                                }
                            }

                            HoverHandler {
                                onHoveredChanged: if (hovered) panel.setSelection(index)
                            }
                            TapHandler {
                                acceptedButtons: Qt.LeftButton
                                onTapped: panel.activate(index)
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: panel.visibleItems.length === 0
                            text: panel.items.length === 0 ? "Clipboard history is empty" : "No matches"
                            color: root.sumi
                            font.family: root.mono
                            font.pixelSize: 11
                        }
                    }
                }

                Rectangle {
                    id: divider
                    visible: !leftPane.stacked
                    x: leftPane.width + 8
                    y: 0
                    width: 1
                    height: body.height
                    color: root.sep
                }

                Item {
                    id: rightPane
                    property bool stacked: leftPane.stacked
                    x: stacked ? 0 : leftPane.width + 18
                    y: stacked ? leftPane.height + 8 : 0
                    width: stacked ? body.width : body.width - x
                    height: stacked ? body.height - y : body.height

                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        color: root.fillIdle
                        radius: root.tileRadius

                        Flickable {
                            id: textFlick
                            anchors.fill: parent
                            anchors.margins: 8
                            visible: panel.selectedItem && panel.selectedItem.kind === "text"
                            clip: true
                            contentWidth: width
                            contentHeight: Math.max(height, textPreview.contentHeight + 8)
                            boundsBehavior: Flickable.StopAtBounds
                            TextEdit {
                                id: textPreview
                                width: textFlick.width
                                height: Math.max(textFlick.height, contentHeight + 8)
                                text: panel.selectedItem ? panel.selectedItem.fullText : ""
                                readOnly: true
                                selectByMouse: true
                                wrapMode: TextEdit.Wrap
                                color: root.ink
                                font.family: root.mono
                                font.pixelSize: 11
                                textFormat: TextEdit.PlainText
                            }
                            ScrollBar.vertical: ScrollBar {
                                policy: ScrollBar.AsNeeded
                                width: 6
                                contentItem: Rectangle { radius: 3; color: root.seal; opacity: 0.65 }
                            }
                        }

                        Image {
                            id: imagePreview
                            anchors.fill: parent
                            anchors.margins: 12
                            visible: panel.selectedItem && panel.selectedItem.kind === "image"
                            source: panel.imageSource(panel.selectedItem)
                            sourceSize.width: Math.max(1, width)
                            sourceSize.height: Math.max(1, height)
                            fillMode: Image.PreserveAspectFit
                            asynchronous: true
                            cache: false
                        }

                        Text {
                            anchors.centerIn: parent
                            width: parent.width - 24
                            visible: panel.selectedItem && panel.selectedItem.kind === "image" && imagePreview.status === Image.Error
                            text: "Image preview unavailable"
                            color: root.sumi
                            font.family: root.mono
                            font.pixelSize: 10
                            horizontalAlignment: Text.AlignHCenter
                        }

                        Column {
                            anchors.centerIn: parent
                            width: parent.width - 24
                            visible: !panel.selectedItem || panel.selectedItem.kind === "other"
                            spacing: 6
                            Text {
                                width: parent.width
                                text: panel.selectedItem ? "Unsupported clipboard entry" : "Select an item to preview"
                                color: root.sumi
                                font.family: root.mono
                                font.pixelSize: 10
                                horizontalAlignment: Text.AlignHCenter
                            }
                            Text {
                                width: parent.width
                                visible: panel.selectedItem && panel.selectedItem.detail.length > 0
                                text: panel.selectedItem ? panel.selectedItem.detail : ""
                                color: root.sumi
                                font.family: root.mono
                                font.pixelSize: 9
                                horizontalAlignment: Text.AlignHCenter
                                wrapMode: Text.Wrap
                            }
                        }
                    }
                }
            }

            Text {
                width: parent.width
                height: 18
                text: "Enter copy  ·  Delete remove  ·  Esc close"
                color: root.sumi
                font.family: root.mono
                font.pixelSize: 9
            }

            Text {
                width: parent.width
                height: statusText.length > 0 ? 14 : 0
                visible: statusText.length > 0
                text: panel.statusText
                color: root.seal
                font.family: root.mono
                font.pixelSize: 9
                elide: Text.ElideRight
            }
        }
    }

    Process {
        id: queryProc
        command: [Quickshell.env("HOME") + "/.local/bin/qs-clipboard", "query", "40"]
        stdout: StdioCollector { onStreamFinished: panel.parse(this.text) }
    }
    Process { id: copyProc }
    Process { id: removeProc }
    Timer { id: refreshTimer; interval: 180; repeat: false; onTriggered: panel.refresh() }

    onVisibleChanged: if (visible) {
        root.activateFocusedPopupScreen()
        query = ""
        statusText = ""
        resetSelection()
        refresh()
        focusTimer.restart()
    }
}
