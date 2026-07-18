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
    property int pendingSelectionIndex: -1
    property string selectedId: ""
    property string query: ""
    property string activeFilter: "all"
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
        return items.filter(function(item) {
            if (activeFilter === "text" && item.kind !== "text") return false
            if (activeFilter === "image" && item.kind !== "image") return false
            return !needle || item.searchKeywords.indexOf(needle) >= 0
        })
    }

    function setSelection(index) {
        var count = visibleItems.length
        var next = count > 0 ? Math.max(0, Math.min(index, count - 1)) : 0
        selectedIndex = next
        selectedId = count > 0 ? visibleItems[next].id : ""
        if (!galleryList) return
        syncingList = true
        galleryList.currentIndex = next
        galleryList.positionViewAtIndex(next, ListView.Contain)
        syncingList = false
    }

    function preserveSelection() {
        var next = 0
        for (var i = 0; i < visibleItems.length; i++) {
            if (visibleItems[i].id === selectedId) { next = i; break }
        }
        Qt.callLater(function() { panel.setSelection(next) })
    }

    function refresh() {
        queryProc.running = false
        queryProc.running = true
    }

    function imageSource(item) {
        if (!item || item.kind !== "image" || !item.imagePath) return ""
        if (item.imagePath.indexOf("file://") === 0) return item.imagePath
        return "file://" + encodeURI(item.imagePath)
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
        pendingSelectionIndex = selectedIndex
        removeProc.command = [Quickshell.env("HOME") + "/.local/bin/qs-clipboard", "delete", row.id]
        removeProc.running = false
        removeProc.running = true
        statusText = "Removing clipboard entry…"
        refreshTimer.restart()
    }

    function editSelectedImage() {
        var row = selectedItem
        if (!row || row.kind !== "image" || !row.imagePath) return
        editProc.command = [Quickshell.env("HOME") + "/.local/bin/qs-clipboard", "edit", row.imagePath]
        editProc.running = false
        editProc.running = true
        root.clipboardVisible = false
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
                var previewType = String(x.preview_type || "").toLowerCase()
                var isImage = previewType === "file"
                var isText = previewType === "text" || (!previewType && !!x.text)
                var preview = String(x.preview || "")
                var fullText = isText ? (preview || String(x.text || "")) : ""
                var mimeType = String(x.mime || x.mime_type || "")
                var timestamp = String(x.subtext || "")
                var label = isImage ? "Image clipboard entry"
                    : (fullText ? fullText.replace(/\s+/g, " ").trim().slice(0, 120) : "Clipboard entry")
                var metadata = [timestamp, mimeType].filter(function(value) { return value.length > 0 }).join(" · ")
                out.push({
                    id: String(x.identifier || ""),
                    kind: isImage ? "image" : (isText ? "text" : "other"),
                    entryType: previewType || "other",
                    label: label,
                    detail: metadata || String(x.provider || "clipboard"),
                    fullText: fullText,
                    previewText: isText ? fullText : "",
                    imagePath: isImage ? preview : "",
                    mimeType: mimeType,
                    timestamp: timestamp,
                    searchKeywords: (label + " " + fullText + " " + metadata + " " + mimeType + " " + previewType).toLowerCase(),
                    icon: isImage ? "" : (isText ? "" : "󰋼")
                })
            }
            items = out.filter(function(item) { return item.id.length > 0 })
            statusText = ""
            if (pendingSelectionIndex >= 0) {
                var nextIndex = pendingSelectionIndex
                pendingSelectionIndex = -1
                Qt.callLater(function() { panel.setSelection(nextIndex) })
            } else {
                preserveSelection()
            }
        } catch (e) {
            statusText = "Clipboard history unavailable"
            items = []
            setSelection(0)
        }
    }

    function handleKey(event) {
        var count = visibleItems.length
        var before = selectedIndex
        var branch = "unhandled"
        if (event.key === Qt.Key_Escape) {
            branch = "close"; root.clipboardVisible = false; event.accepted = true
        } else if (event.key === Qt.Key_Right || event.key === Qt.Key_Down) {
            branch = "moveNext"; if (count > 0) setSelection((selectedIndex + 1) % count); event.accepted = true
        } else if (event.key === Qt.Key_Left || event.key === Qt.Key_Up) {
            branch = "movePrevious"; if (count > 0) setSelection((selectedIndex - 1 + count) % count); event.accepted = true
        } else if (event.key === Qt.Key_PageDown) {
            branch = "pageDown"; if (count > 0) setSelection(Math.min(count - 1, selectedIndex + 5)); event.accepted = true
        } else if (event.key === Qt.Key_PageUp) {
            branch = "pageUp"; if (count > 0) setSelection(Math.max(0, selectedIndex - 5)); event.accepted = true
        } else if (event.key === Qt.Key_Home && searchField.text.length === 0) {
            branch = "home"; if (count > 0) setSelection(0); event.accepted = true
        } else if (event.key === Qt.Key_End && searchField.text.length === 0) {
            branch = "end"; if (count > 0) setSelection(count - 1); event.accepted = true
        } else if (event.key === Qt.Key_Delete && searchField.text.length === 0) {
            branch = "remove"; remove(selectedIndex); event.accepted = true
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            branch = "copy"; activate(selectedIndex); event.accepted = true
        }
        inputDebugLog("key=" + event.key + " text=" + event.text + " modifiers=" + event.modifiers
            + " autoRepeat=" + event.isAutoRepeat + " before=" + before + " count=" + count
            + " branch=" + branch + " after=" + selectedIndex + " accepted=" + event.accepted)
    }

    Timer {
        id: focusTimer
        interval: 40
        repeat: false
        onTriggered: if (root.clipboardVisible && panel.visible) searchField.forceActiveFocus()
    }

    MouseArea { anchors.fill: parent; enabled: root.clipboardVisible; onClicked: root.clipboardVisible = false }

    Rectangle {
        id: card
        width: Math.min(940, parent.width - 24)
        height: Math.min(parent.height - 48, 650)
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
            spacing: 9

            Row {
                width: parent.width
                height: 34
                spacing: 8

                Text {
                    width: Math.max(120, parent.width - searchBox.width - filterRow.width - 16)
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Clipboard History"
                    color: root.ink
                    font.family: root.mono
                    font.pixelSize: 13
                    font.letterSpacing: 2
                    elide: Text.ElideRight
                }

                Rectangle {
                    id: searchBox
                    width: Math.min(280, Math.max(150, card.width * 0.3))
                    height: 34
                    radius: root.tileRadius
                    color: root.fillIdle
                    border.color: searchField.activeFocus ? root.seal : root.sep
                    border.width: 1
                    TextInput {
                        id: searchField
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        verticalAlignment: TextInput.AlignVCenter
                        text: panel.query
                        color: root.ink
                        selectionColor: root.fillHover
                        selectedTextColor: root.ink
                        font.family: root.mono
                        font.pixelSize: 11
                        clip: true
                        Keys.priority: Keys.BeforeItem
                        onTextChanged: { if (panel.query !== text) panel.query = text; panel.preserveSelection() }
                        Keys.onPressed: function(event) { panel.handleKey(event) }
                    }
                    Text {
                        anchors.left: parent.left; anchors.leftMargin: 12; anchors.verticalCenter: parent.verticalCenter
                        visible: searchField.text.length === 0 && !searchField.activeFocus
                        text: "Search clipboard…"; color: root.sumi; font.family: root.mono; font.pixelSize: 11
                    }
                }

                Row {
                    id: filterRow
                    height: 34
                    spacing: 3
                    Repeater {
                        model: [{ key: "all", icon: "󰒔", tip: "All" }, { key: "text", icon: "", tip: "Text" }, { key: "image", icon: "", tip: "Images" }]
                        Rectangle {
                            required property var modelData
                            width: 34; height: 34; radius: root.tileRadius
                            color: panel.activeFilter === modelData.key ? root.fillHover : root.fillIdle
                            border.color: panel.activeFilter === modelData.key ? root.seal : root.sep
                            border.width: 1
                            Text { anchors.centerIn: parent; text: modelData.icon; color: panel.activeFilter === modelData.key ? root.seal : root.sumi; font.family: root.mono; font.pixelSize: 12 }
                            HoverHandler { id: filterHover }
                            ToolTip.visible: filterHover.hovered
                            ToolTip.text: modelData.tip
                            TapHandler { onTapped: { panel.activeFilter = modelData.key; panel.preserveSelection() } }
                        }
                    }
                }
            }

            ListView {
                id: galleryList
                width: parent.width
                height: 112
                orientation: ListView.Horizontal
                clip: true
                interactive: true
                spacing: 8
                cacheBuffer: 180
                model: panel.visibleItems
                currentIndex: 0
                keyNavigationEnabled: false
                boundsBehavior: Flickable.StopAtBounds
                onCurrentIndexChanged: {
                    if (!panel.syncingList && currentIndex >= 0 && currentIndex < panel.visibleItems.length)
                        panel.setSelection(currentIndex)
                }
                ScrollBar.horizontal: ScrollBar {
                    policy: ScrollBar.AsNeeded
                    height: 5
                    contentItem: Rectangle { radius: 3; color: root.seal; opacity: 0.65 }
                    background: Rectangle { radius: 3; color: root.fillIdle; opacity: 0.35 }
                }

                delegate: Item {
                    required property int index
                    required property var modelData
                    width: 148
                    height: 104

                    Rectangle {
                        anchors.fill: parent
                        radius: root.tileRadius
                        color: panel.selectedIndex === index ? root.fillHover : root.fillIdle
                        border.color: panel.selectedIndex === index ? root.seal : root.sep
                        border.width: panel.selectedIndex === index ? 2 : 1

                        Image {
                            id: thumb
                            anchors.fill: parent
                            anchors.margins: 5
                            visible: modelData.kind === "image"
                            source: visible ? panel.imageSource(modelData) : ""
                            sourceSize.width: 160
                            sourceSize.height: 100
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            cache: true
                        }
                        Text {
                            anchors.fill: parent
                            anchors.margins: 9
                            visible: modelData.kind === "text"
                            text: modelData.previewText
                            color: root.ink
                            font.family: root.mono
                            font.pixelSize: 10
                            wrapMode: Text.Wrap
                            maximumLineCount: 3
                            elide: Text.ElideRight
                        }
                        Text {
                            anchors.centerIn: parent
                            visible: modelData.kind === "other" || (modelData.kind === "image" && thumb.status === Image.Error)
                            text: modelData.kind === "image" ? "Image unavailable" : modelData.icon
                            color: root.sumi
                            font.family: root.mono
                            font.pixelSize: modelData.kind === "image" ? 9 : 18
                        }
                        Rectangle {
                            anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
                            height: 20; radius: root.tileRadius; color: root.bg; opacity: 0.86
                            Text {
                                anchors.fill: parent; anchors.leftMargin: 6; anchors.rightMargin: 6
                                verticalAlignment: Text.AlignVCenter
                                text: modelData.timestamp
                                color: root.sumi; font.family: root.mono; font.pixelSize: 7; elide: Text.ElideRight
                            }
                        }
                    }
                    HoverHandler { onHoveredChanged: if (hovered) panel.setSelection(index) }
                    TapHandler { acceptedButtons: Qt.LeftButton; onTapped: panel.setSelection(index) }
                }

                Text {
                    anchors.centerIn: parent
                    visible: panel.visibleItems.length === 0
                    text: panel.items.length === 0 ? "Clipboard history is empty" : "No matching clipboard items"
                    color: root.sumi; font.family: root.mono; font.pixelSize: 11
                }
            }

            Rectangle {
                id: preview
                width: parent.width
                height: parent.height - 34 - galleryList.height - footer.height - (statusText.length > 0 ? 14 : 0) - 36
                radius: root.tileRadius
                color: root.fillIdle
                border.color: root.sep
                border.width: 1

                Flickable {
                    id: textFlick
                    anchors.fill: parent
                    anchors.margins: 14
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
                    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded; width: 6; contentItem: Rectangle { radius: 3; color: root.seal; opacity: 0.65 } }
                }

                Image {
                    id: imagePreview
                    anchors.fill: parent
                    anchors.margins: 14
                    visible: panel.selectedItem && panel.selectedItem.kind === "image"
                    source: visible ? panel.imageSource(panel.selectedItem) : ""
                    sourceSize.width: Math.max(1, width)
                    sourceSize.height: Math.max(1, height)
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                    cache: false
                }

                Column {
                    anchors.centerIn: parent
                    width: parent.width - 28
                    spacing: 6
                    visible: !panel.selectedItem || panel.selectedItem.kind === "other"
                        || (panel.selectedItem.kind === "image" && imagePreview.status === Image.Error)
                    Text {
                        width: parent.width
                        text: panel.selectedItem && panel.selectedItem.kind === "image" ? "Image preview unavailable"
                            : (panel.selectedItem ? "Unsupported clipboard entry" : "Select an item to preview")
                        color: root.sumi; font.family: root.mono; font.pixelSize: 10; horizontalAlignment: Text.AlignHCenter
                    }
                    Text {
                        width: parent.width
                        visible: panel.selectedItem && panel.selectedItem.detail.length > 0
                        text: panel.selectedItem ? panel.selectedItem.detail : ""
                        color: root.sumi; font.family: root.mono; font.pixelSize: 9
                        horizontalAlignment: Text.AlignHCenter; wrapMode: Text.Wrap
                    }
                }
            }

            Row {
                id: footer
                width: parent.width
                height: 18
                Text {
                    width: Math.max(180, parent.width - editButton.width - timestampText.width - 16)
                    text: "←/→ browse  ·  Enter copy  ·  Delete remove  ·  Esc close"
                    color: root.sumi; font.family: root.mono; font.pixelSize: 9; elide: Text.ElideRight
                }
                Rectangle {
                    id: editButton
                    visible: panel.selectedItem && panel.selectedItem.kind === "image"
                    width: visible ? 72 : 0
                    height: 18
                    radius: root.tileRadius
                    color: editHover.hovered ? root.fillHover : root.fillIdle
                    border.color: root.seal
                    border.width: 1
                    Row {
                        anchors.centerIn: parent
                        spacing: 5
                        Text { text: ""; color: root.seal; font.family: root.mono; font.pixelSize: 9 }
                        Text { text: "Edit"; color: root.ink; font.family: root.mono; font.pixelSize: 9 }
                    }
                    HoverHandler { id: editHover }
                    TapHandler { acceptedButtons: Qt.LeftButton; onTapped: panel.editSelectedImage() }
                }
                Text {
                    id: timestampText
                    width: Math.min(270, parent.width * 0.34)
                    text: panel.selectedItem ? panel.selectedItem.timestamp : ""
                    color: root.sumi; font.family: root.mono; font.pixelSize: 9
                    horizontalAlignment: Text.AlignRight; elide: Text.ElideLeft
                }
            }

            Text {
                width: parent.width
                height: statusText.length > 0 ? 14 : 0
                visible: statusText.length > 0
                text: panel.statusText
                color: root.seal; font.family: root.mono; font.pixelSize: 9; elide: Text.ElideRight
            }
        }
    }

    Process {
        id: queryProc
        command: [Quickshell.env("HOME") + "/.local/bin/qs-clipboard", "query", "120"]
        stdout: StdioCollector { onStreamFinished: panel.parse(this.text) }
    }
    Process { id: copyProc }
    Process { id: removeProc }
    Process { id: editProc }
    Timer { id: refreshTimer; interval: 180; repeat: false; onTriggered: panel.refresh() }

    onVisibleChanged: if (visible) {
        root.activateFocusedPopupScreen()
        query = ""
        activeFilter = "all"
        statusText = ""
        pendingSelectionIndex = -1
        selectedId = ""
        setSelection(0)
        refresh()
        focusTimer.restart()
    }
}
