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
    WlrLayershell.namespace: "quickshell-emoji-picker"
    WlrLayershell.keyboardFocus: root.emojiPickerVisible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    visible: root.emojiPickerVisible

    property var items: []
    property int selectedIndex: 0
    property string query: ""
    property string statusText: ""
    property bool acceptQueryResults: false
    readonly property var featuredItems: [
        { id: "featured-01", emoji: "😂", label: "face with tears of joy" },
        { id: "featured-02", emoji: "😊", label: "smiling face with smiling eyes" },
        { id: "featured-03", emoji: "❤️", label: "red heart" },
        { id: "featured-04", emoji: "👍", label: "thumbs up" },
        { id: "featured-05", emoji: "🔥", label: "fire" },
        { id: "featured-06", emoji: "🎉", label: "party popper" },
        { id: "featured-07", emoji: "🙏", label: "folded hands" },
        { id: "featured-08", emoji: "💻", label: "laptop" },
        { id: "featured-09", emoji: "🚀", label: "rocket" },
        { id: "featured-10", emoji: "😀", label: "grinning face" },
        { id: "featured-11", emoji: "😁", label: "beaming face with smiling eyes" },
        { id: "featured-12", emoji: "😅", label: "grinning face with sweat" },
        { id: "featured-13", emoji: "🤣", label: "rolling on the floor laughing" },
        { id: "featured-14", emoji: "😃", label: "grinning face with big eyes" },
        { id: "featured-15", emoji: "😄", label: "grinning face with smiling eyes" },
        { id: "featured-16", emoji: "😋", label: "face savoring food" },
        { id: "featured-17", emoji: "😇", label: "smiling face with halo" },
        { id: "featured-18", emoji: "😉", label: "winking face" },
        { id: "featured-19", emoji: "😍", label: "smiling face with heart-eyes" },
        { id: "featured-20", emoji: "🥰", label: "smiling face with hearts" },
        { id: "featured-21", emoji: "😘", label: "face blowing a kiss" },
        { id: "featured-22", emoji: "😗", label: "kissing face" },
        { id: "featured-23", emoji: "😙", label: "kissing face with smiling eyes" },
        { id: "featured-24", emoji: "😚", label: "kissing face with closed eyes" },
        { id: "featured-25", emoji: "😛", label: "face with tongue" },
        { id: "featured-26", emoji: "😜", label: "winking face with tongue" },
        { id: "featured-27", emoji: "🤪", label: "zany face" },
        { id: "featured-28", emoji: "😝", label: "squinting face with tongue" },
        { id: "featured-29", emoji: "🤑", label: "money-mouth face" },
        { id: "featured-30", emoji: "🤗", label: "smiling face with open hands" },
        { id: "featured-31", emoji: "🤭", label: "face with hand over mouth" },
        { id: "featured-32", emoji: "🫢", label: "face with open eyes and hand over mouth" },
        { id: "featured-33", emoji: "🤫", label: "shushing face" },
        { id: "featured-34", emoji: "🤔", label: "thinking face" },
        { id: "featured-35", emoji: "🫡", label: "saluting face" },
        { id: "featured-36", emoji: "😐", label: "neutral face" },
        { id: "featured-37", emoji: "😕", label: "confused face" },
        { id: "featured-38", emoji: "🙄", label: "face with rolling eyes" },
        { id: "featured-39", emoji: "✨", label: "sparkles" },
        { id: "featured-40", emoji: "⭐", label: "star" },
        { id: "featured-41", emoji: "🌙", label: "crescent moon" },
        { id: "featured-42", emoji: "☀️", label: "sun" },
        { id: "featured-43", emoji: "🌈", label: "rainbow" },
        { id: "featured-44", emoji: "🎵", label: "musical note" },
        { id: "featured-45", emoji: "💯", label: "hundred points" }
    ]
    readonly property int rowHeight: 38
    readonly property int visibleRows: Math.max(1, Math.floor(emojiList.height / rowHeight))
    readonly property var selectedItem: items.length > 0
        ? items[Math.max(0, Math.min(selectedIndex, items.length - 1))] : null
    readonly property bool inputDebug: Quickshell.env("QS_EMOJI_INPUT_DEBUG") === "1"

    function inputDebugLog(message) {
        if (inputDebug) console.log("Emoji input: " + message)
    }

    function setSelection(index) {
        selectedIndex = items.length > 0 ? Math.max(0, Math.min(index, items.length - 1)) : 0
        if (items.length > 0) {
            emojiList.currentIndex = selectedIndex
            emojiList.positionViewAtIndex(selectedIndex, ListView.Contain)
        }
    }

    function refresh() {
        acceptQueryResults = true
        queryProc.command = [Quickshell.env("HOME") + "/.local/bin/qs-emoji", "query", query.trim(), "180"]
        queryProc.running = false
        queryProc.running = true
        statusText = ""
    }

    function parse(text) {
        if (!acceptQueryResults) return
        var next = []
        var lines = String(text || "").trim().split("\n")
        try {
            for (var i = 0; i < lines.length; i++) {
                if (!lines[i].trim()) continue
                var response = JSON.parse(lines[i])
                var item = response.item || null
                if (!item || !item.identifier || !item.icon) continue
                next.push({
                    id: String(item.identifier),
                    emoji: String(item.icon),
                    label: String(item.text || "Symbol")
                })
            }
            if (query.trim().length === 0) {
                var merged = featuredItems.slice()
                var seen = {}
                for (var featuredIndex = 0; featuredIndex < merged.length; featuredIndex++)
                    seen[merged[featuredIndex].emoji] = true
                for (var resultIndex = 0; resultIndex < next.length; resultIndex++) {
                    if (!seen[next[resultIndex].emoji]) {
                        seen[next[resultIndex].emoji] = true
                        merged.push(next[resultIndex])
                    }
                }
                next = merged
            }
            items = next
            setSelection(0)
            statusText = next.length === 0 ? "No matching emoji or symbols" : ""
        } catch (e) {
            items = []
            setSelection(0)
            statusText = "Emoji catalogue unavailable"
        }
    }

    function activate(index) {
        setSelection(index)
        var item = selectedItem
        if (!item) return
        selectProc.command = [Quickshell.env("HOME") + "/.local/bin/qs-emoji", "select", item.emoji]
        root.emojiPickerVisible = false
        pasteTimer.restart()
    }

    function unicodeLabel(value) {
        var out = []
        var text = String(value || "")
        for (var i = 0; i < text.length; i++) {
            var point = text.codePointAt(i)
            out.push("U+" + point.toString(16).toUpperCase().padStart(4, "0"))
            if (point > 0xFFFF) i++
        }
        return out.join("  ")
    }

    function handleKey(event) {
        var count = items.length
        var before = selectedIndex
        var branch = "unhandled"
        if (event.key === Qt.Key_Escape) {
            branch = "close"; root.emojiPickerVisible = false; event.accepted = true
        } else if (event.key === Qt.Key_Right) {
            branch = "right"; if (count > 0) setSelection((selectedIndex + 1) % count); event.accepted = true
        } else if (event.key === Qt.Key_Left) {
            branch = "left"; if (count > 0) setSelection((selectedIndex - 1 + count) % count); event.accepted = true
        } else if (event.key === Qt.Key_Down) {
            branch = "down"; if (count > 0) setSelection(Math.min(count - 1, selectedIndex + 1)); event.accepted = true
        } else if (event.key === Qt.Key_Up) {
            branch = "up"; if (count > 0) setSelection(Math.max(0, selectedIndex - 1)); event.accepted = true
        } else if (event.key === Qt.Key_PageDown) {
            branch = "pageDown"; if (count > 0) setSelection(Math.min(count - 1, selectedIndex + visibleRows)); event.accepted = true
        } else if (event.key === Qt.Key_PageUp) {
            branch = "pageUp"; if (count > 0) setSelection(Math.max(0, selectedIndex - visibleRows)); event.accepted = true
        } else if (event.key === Qt.Key_Home && keyboardInput.text.length === 0) {
            branch = "home"; if (count > 0) setSelection(0); event.accepted = true
        } else if (event.key === Qt.Key_End && keyboardInput.text.length === 0) {
            branch = "end"; if (count > 0) setSelection(count - 1); event.accepted = true
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            branch = "activate"; activate(selectedIndex); event.accepted = true
        }
        inputDebugLog("key=" + event.key + " text=" + event.text + " before=" + before
            + " count=" + count + " branch=" + branch + " after=" + selectedIndex)
    }

    Timer {
        id: focusTimer
        interval: 40
        repeat: false
        onTriggered: if (root.emojiPickerVisible && panel.visible) keyboardInput.forceActiveFocus()
    }
    Timer { id: searchTimer; interval: 90; repeat: false; onTriggered: panel.refresh() }
    Timer {
        id: pasteTimer
        interval: 80
        repeat: false
        onTriggered: { selectProc.running = false; selectProc.running = true }
    }

    MouseArea { anchors.fill: parent; enabled: root.emojiPickerVisible; onClicked: root.emojiPickerVisible = false }

    Rectangle {
        id: card
        width: Math.min(560, parent.width - 24)
        height: Math.min(430, parent.height - 48)
        x: Math.round((parent.width - width) / 2)
        y: Math.round((parent.height - height) / 2)
        radius: root.pillRadius
        color: Qt.rgba(root.bg.r, root.bg.g, root.bg.b, 1)
        border.color: root.pillBorder
        border.width: root.pillBorderW
        clip: true
        PillShadow { theme: root }
        MouseArea { anchors.fill: parent; onClicked: {} }

        TextInput {
            id: keyboardInput
            width: 1
            height: 1
            opacity: 0
            color: "transparent"
            cursorVisible: false
            clip: true
            Keys.priority: Keys.BeforeItem
            Keys.onPressed: function(event) { panel.handleKey(event) }
            onTextChanged: {
                if (panel.query !== text) panel.query = text
                searchTimer.restart()
            }
        }

        ListView {
            id: emojiList
            anchors.fill: parent
            anchors.margins: 12
            clip: true
            interactive: true
            spacing: 3
            model: panel.items
            currentIndex: 0
            keyNavigationEnabled: false
            cacheBuffer: panel.rowHeight * 5
            boundsBehavior: Flickable.StopAtBounds
            WheelHandler {
                onWheel: function(event) {
                    var direction = event.angleDelta.y < 0 ? 1 : -1
                    var maximum = Math.max(0, emojiList.contentHeight - emojiList.height)
                    emojiList.contentY = Math.max(0, Math.min(maximum,
                        emojiList.contentY + direction * panel.rowHeight * 3))
                    event.accepted = true
                }
            }
            ScrollBar.vertical: ScrollBar {
                id: emojiScrollBar
                policy: ScrollBar.AlwaysOn
                interactive: true
                width: 7
                rightPadding: 1
                contentItem: Rectangle {
                    implicitWidth: 5
                    radius: 3
                    color: root.seal
                    opacity: emojiScrollBar.pressed || emojiScrollBar.hovered ? 0.9 : 0.62
                }
                background: Rectangle {
                    implicitWidth: 5
                    radius: 3
                    color: root.fillIdle
                    opacity: 0.7
                }
            }

            delegate: Rectangle {
                required property int index
                required property var modelData
                width: emojiList.width
                height: panel.rowHeight
                radius: root.tileRadius
                color: panel.selectedIndex === index ? root.fillHover : root.fillIdle
                border.color: panel.selectedIndex === index ? root.seal : root.sep
                border.width: 1
                Text {
                    id: emojiGlyph
                    anchors.left: parent.left
                    anchors.leftMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    width: 38
                    text: modelData.emoji
                    color: root.ink
                    font.pixelSize: 21
                    horizontalAlignment: Text.AlignHCenter
                }
                Text {
                    anchors.left: emojiGlyph.right
                    anchors.leftMargin: 10
                    anchors.right: codePoint.left
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    text: modelData.label
                    color: root.ink
                    font.family: root.mono
                    font.pixelSize: 10
                    elide: Text.ElideRight
                }
                Text {
                    id: codePoint
                    anchors.right: parent.right
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    width: 148
                    text: panel.unicodeLabel(modelData.emoji)
                    color: root.sumi
                    font.family: root.mono
                    font.pixelSize: 9
                    horizontalAlignment: Text.AlignRight
                    elide: Text.ElideRight
                }
                HoverHandler { onHoveredChanged: if (hovered) panel.setSelection(index) }
                TapHandler { acceptedButtons: Qt.LeftButton; onTapped: panel.activate(index) }
            }

            Text {
                anchors.centerIn: parent
                visible: panel.items.length === 0
                text: panel.statusText
                color: root.sumi
                font.family: root.mono
                font.pixelSize: 10
            }
        }
    }

    Process {
        id: queryProc
        stdout: StdioCollector { onStreamFinished: panel.parse(this.text) }
        onExited: function(code) {
            if (panel.acceptQueryResults && code !== 0 && panel.items.length === 0)
                panel.statusText = "Emoji catalogue unavailable"
        }
    }
    Process { id: selectProc }

    onVisibleChanged: if (visible) {
        root.activateFocusedPopupScreen()
        query = ""
        keyboardInput.text = ""
        items = []
        selectedIndex = 0
        statusText = ""
        refresh()
        focusTimer.restart()
    }
}
