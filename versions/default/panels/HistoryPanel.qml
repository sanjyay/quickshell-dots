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
    WlrLayershell.namespace: "quickshell-history"
    WlrLayershell.keyboardFocus: root.clipboardVisible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    visible: root.clipboardVisible

    property var items: []
    property var clipboardItems: []
    property var screenshotItems: []
    property var recordingItems: []
    property int selectedIndex: 0
    property int pendingSelectionIndex: -1
    property string selectedId: ""
    property string query: ""
    property string activeFilter: "all"
    property string statusText: ""
    property bool syncingList: false
    property bool clipboardLoaded: false
    property bool screenshotsLoaded: false
    property bool recordingsLoaded: false
    readonly property string historyPath: Quickshell.env("HOME")
        + "/.local/state/omarchy/clipboard-history.json"
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
            if (activeFilter === "image" && item.kind !== "image" && item.kind !== "screenshot") return false
            return !needle || item.searchKeywords.indexOf(needle) >= 0
        })
    }

    function setSelection(index) {
        var count = visibleItems.length
        var next = count > 0 ? Math.max(0, Math.min(index, count - 1)) : 0
        selectedIndex = next
        selectedId = count > 0 ? visibleItems[next].id : ""
    }

    function preserveSelection() {
        var next = 0
        for (var i = 0; i < visibleItems.length; i++) {
            if (visibleItems[i].id === selectedId) { next = i; break }
        }
        Qt.callLater(function() { panel.setSelection(next) })
    }

    function refresh() {
        clipboardLoaded = false
        screenshotsLoaded = false
        recordingsLoaded = false
        queryProc.running = false
        queryProc.running = true
        screenshotProc.running = false
        screenshotProc.running = true
        recordingProc.running = false
        recordingProc.running = true
    }

    function imageSource(item) {
        if (!item || (item.kind !== "image" && item.kind !== "screenshot" && item.kind !== "recording") || !item.imagePath) return ""
        if (item.imagePath.indexOf("file://") === 0) return item.imagePath
        return "file://" + encodeURI(item.imagePath)
    }

    function finishRefresh() {
        if (!clipboardLoaded || !screenshotsLoaded || !recordingsLoaded) return
        var screenshotsBySecond = {}
        screenshotItems.forEach(function(item) { screenshotsBySecond[Math.floor(item.sortKey)] = true })
        var uniqueClipboardItems = clipboardItems.filter(function(item) {
            return item.kind !== "image" || !screenshotsBySecond[Math.floor(item.sortKey)]
        })
        items = recordingItems.concat(screenshotItems, uniqueClipboardItems).sort(function(a, b) {
            if (a.sortKey !== b.sortKey) return b.sortKey - a.sortKey
            return a.id < b.id ? 1 : (a.id > b.id ? -1 : 0)
        })
        statusText = ""
        if (pendingSelectionIndex >= 0) {
            var nextIndex = pendingSelectionIndex
            pendingSelectionIndex = -1
            Qt.callLater(function() { panel.setSelection(nextIndex) })
        } else if (selectedId.length > 0) {
            preserveSelection()
        } else {
            setSelection(0)
        }
    }

    function activate(index) {
        setSelection(index)
        var row = selectedItem
        if (!row) return
        if (row.kind === "recording") {
            var uri = "file://" + encodeURI(row.filePath)
            Quickshell.execDetached(["wl-copy", "--type", "text/uri-list", uri])
            root.clipboardVisible = false
            return
        }
        if (row.kind === "screenshot") {
            Quickshell.execDetached(["bash", "-c", "wl-copy --type image/png < \"$1\"", "history-copy", row.filePath])
            root.clipboardVisible = false
            return
        }
        if (row.kind === "image") {
            Quickshell.execDetached([
                Quickshell.env("OMARCHY_PATH") + "/bin/omarchy-clipboard-paste-file",
                row.mimeType, row.imagePath
            ])
        } else {
            Quickshell.execDetached([
                Quickshell.env("OMARCHY_PATH") + "/bin/omarchy-clipboard-paste-text",
                "--shift-insert", "--history-index", String(row.nativeHistoryIndex)
            ])
        }
        root.clipboardVisible = false
    }

    function openRecording(row) {
        if (!row || row.kind !== "recording" || !row.filePath) return
        Quickshell.execDetached(["omacut", row.filePath])
        root.clipboardVisible = false
    }

    function remove(index) {
        setSelection(index)
        var row = selectedItem
        if (!row) return
        pendingSelectionIndex = selectedIndex
        removeProc.command = row.kind === "recording" || row.kind === "screenshot"
            ? ["bash", "-c", "gio trash -- \"$1\" 2>/dev/null || trash-put -- \"$1\" 2>/dev/null", "history-remove", row.filePath]
            : ["python3", "-c", [
                "import json,os,sys,tempfile",
                "p=sys.argv[1]; i=int(sys.argv[2])",
                "data=json.load(open(p,encoding='utf-8'))",
                "data.pop(i)",
                "fd,tmp=tempfile.mkstemp(prefix='.clipboard-history.',dir=os.path.dirname(p),text=True)",
                "f=os.fdopen(fd,'w',encoding='utf-8')",
                "json.dump(data,f,ensure_ascii=False,indent=2); f.write('\\n'); f.close()",
                "os.replace(tmp,p)"
            ].join(";"), panel.historyPath, String(row.nativeHistoryIndex)]
        removeProc.running = false
        removeProc.running = true
        statusText = "Removing history entry…"
        refreshTimer.restart()
    }

    function editSelectedImage() {
        var row = selectedItem
        if (!row || (row.kind !== "image" && row.kind !== "screenshot") || !row.imagePath) return
        editProc.command = ["satty", "--filename", row.imagePath,
            "--output-filename", row.imagePath,
            "--actions-on-enter", "save-to-clipboard",
            "--save-after-copy", "--copy-command", "wl-copy"]
        editProc.running = false
        editProc.running = true
        root.clipboardVisible = false
    }

    function parse(text) {
        try {
            var raw = JSON.parse(String(text || "[]"))
            if (!Array.isArray(raw)) raw = []

            var out = []
            var fallbackNow = Date.now() / 1000
            for (var i = 0; i < raw.length; i++) {
                var x = raw[i] || {}
                var previewType = String(x.type || "").toLowerCase()
                var isImage = previewType === "image" && !!x.path
                var isText = previewType === "text" && typeof x.text === "string"
                var fullText = isText ? String(x.text || "") : ""
                var mimeType = String(x.mime || "")
                var timestamp = String(x.capturedAt || "")
                var parsedTimestamp = Date.parse(timestamp)
                // Quattro's native store is newest-first but most text entries
                // have no timestamp. Give that ordering realistic separation so
                // real screenshot/recording mtimes are not buried behind it.
                var eventTime = isNaN(parsedTimestamp)
                    ? fallbackNow - i * 60 : parsedTimestamp / 1000
                var label = isImage ? "Image clipboard entry"
                    : (fullText ? fullText.replace(/\s+/g, " ").trim().slice(0, 120) : "Clipboard entry")
                var metadata = [timestamp, mimeType].filter(function(value) { return value.length > 0 }).join(" · ")
                out.push({
                    id: "native:" + i,
                    kind: isImage ? "image" : (isText ? "text" : "other"),
                    entryType: previewType || "other",
                    label: label,
                    detail: metadata || String(x.provider || "clipboard"),
                    fullText: fullText,
                    previewText: isText ? fullText : "",
                    imagePath: isImage ? String(x.path || "") : "",
                    mimeType: mimeType,
                    nativeHistoryIndex: i,
                    timestamp: timestamp,
                    sortKey: eventTime,
                    searchKeywords: (label + " " + fullText + " " + metadata + " " + mimeType + " " + previewType).toLowerCase(),
                    icon: isImage ? "" : (isText ? "" : "󰋼")
                })
            }
            clipboardItems = out.filter(function(item) {
                return item.kind === "text" || item.kind === "image"
            })
            clipboardLoaded = true
            finishRefresh()
        } catch (e) {
            statusText = "Clipboard history unavailable"
            clipboardItems = []
            clipboardLoaded = true
            finishRefresh()
        }
    }

    function parseRecordings(text) {
        recordingItems = parseMediaFiles(text, "recording")
        recordingsLoaded = true
        finishRefresh()
    }

    function parseScreenshots(text) {
        screenshotItems = parseMediaFiles(text, "screenshot")
        screenshotsLoaded = true
        finishRefresh()
    }

    function parseMediaFiles(text, kind) {
        var out = []
        var lines = String(text || "").trim().split("\n")
        for (var i = 0; i < lines.length; i++) {
            var fields = lines[i].split("\t")
            var eventTime = Number(fields.shift())
            var path = fields.join("\t").trim()
            if (!path) continue
            var name = path.split("/").pop()
            var stem = name.replace(/\.[^.]+$/, "")
            var prefix = kind === "recording" ? /^screenrecording-/ : /^screenshot-/
            var stamp = stem.replace(prefix, "").replace("_", "  ")
            out.push({
                id: kind + ":" + path,
                kind: kind,
                entryType: kind,
                label: stem.replace(prefix, kind === "recording" ? "Screen recording · " : "Screenshot · "),
                detail: stamp,
                fullText: "",
                previewText: "",
                imagePath: kind === "recording"
                    ? Quickshell.env("HOME") + "/.cache/quickshell-history-thumbs/" + stem + ".jpg" : path,
                filePath: path,
                mimeType: kind === "recording" ? "video" : "image/png",
                timestamp: stamp,
                sortKey: isFinite(eventTime) && eventTime > 0 ? eventTime : i,
                searchKeywords: (name + " " + (kind === "recording" ? "screen recording video " : "screenshot image ") + stamp).toLowerCase(),
                icon: kind === "recording" ? "" : ""
            })
        }
        return out
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
        } else if (event.key === Qt.Key_Home && query.length === 0) {
            branch = "home"; if (count > 0) setSelection(0); event.accepted = true
        } else if (event.key === Qt.Key_End && query.length === 0) {
            branch = "end"; if (count > 0) setSelection(count - 1); event.accepted = true
        } else if (event.key === Qt.Key_Delete && query.length === 0) {
            branch = "remove"; remove(selectedIndex); event.accepted = true
        } else if (event.key === Qt.Key_E && selectedItem
                   && (selectedItem.kind === "image" || selectedItem.kind === "screenshot")) {
            branch = "edit"; editSelectedImage(); event.accepted = true
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            branch = "copy"; activate(selectedIndex); event.accepted = true
        } else if (event.key === Qt.Key_Backspace) {
            query = query.slice(0, -1); preserveSelection(); searchResetTimer.restart(); event.accepted = true
        } else if (event.text && event.text.length === 1 && event.text.charCodeAt(0) >= 32) {
            query += event.text
            preserveSelection()
            searchResetTimer.restart()
            event.accepted = true
        }
        inputDebugLog("key=" + event.key + " text=" + event.text + " modifiers=" + event.modifiers
            + " autoRepeat=" + event.isAutoRepeat + " before=" + before + " count=" + count
            + " branch=" + branch + " after=" + selectedIndex + " accepted=" + event.accepted)
    }

    Timer {
        id: focusTimer
        interval: 40
        repeat: false
        onTriggered: if (root.clipboardVisible && panel.visible) fanFocus.forceActiveFocus()
    }
    Timer { id: searchResetTimer; interval: 1200; onTriggered: { panel.query = ""; panel.preserveSelection() } }

    Rectangle {
        id: blurSurface
        anchors.fill: parent
        color: Qt.rgba(root.paper.r, root.paper.g, root.paper.b, 0.28)
        opacity: root.clipboardVisible ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 170; easing.type: Easing.OutCubic } }
        MouseArea { anchors.fill: parent; onClicked: root.clipboardVisible = false }
    }

    Item {
        id: fanFocus
        anchors.fill: parent
        focus: root.clipboardVisible
        Keys.priority: Keys.BeforeItem
        Keys.onPressed: function(event) { panel.handleKey(event) }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            y: Math.max(60, parent.height * 0.11)
            text: panel.query.length > 0 ? panel.query : "HISTORY"
            color: root.ink
            font.family: root.mono
            font.pixelSize: panel.query.length > 0 ? 16 : 12
            font.letterSpacing: panel.query.length > 0 ? 0.5 : 4
            opacity: 0.82
        }

        Repeater {
            model: panel.visibleItems
            delegate: Rectangle {
                id: historyCard
                required property int index
                required property var modelData
                readonly property int relativeIndex: index - panel.selectedIndex
                readonly property int distance: Math.abs(relativeIndex)
                readonly property bool selected: relativeIndex === 0

                visible: distance <= 4
                width: Math.min(330, panel.width * 0.28)
                height: Math.min(430, panel.height * 0.62)
                x: Math.round((panel.width - width) / 2 + relativeIndex * Math.min(132, panel.width * 0.11))
                y: Math.round((panel.height - height) / 2 + distance * 24 + (selected ? -12 : 10))
                z: 20 - distance
                rotation: relativeIndex * 9
                scale: selected ? 1.08 : Math.max(0.78, 1 - distance * 0.065)
                opacity: distance <= 3 ? (selected ? 1 : 0.88 - distance * 0.12) : 0.42
                transformOrigin: Item.Bottom
                radius: Math.max(root.pillRadius, 18)
                color: Qt.rgba(root.paper.r, root.paper.g, root.paper.b, selected ? 0.96 : 0.88)
                border.color: selected ? root.seal : Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.24)
                border.width: selected ? 2 : 1
                clip: true

                Behavior on x { NumberAnimation { duration: 210; easing.type: Easing.OutCubic } }
                Behavior on y { NumberAnimation { duration: 210; easing.type: Easing.OutCubic } }
                Behavior on rotation { NumberAnimation { duration: 210; easing.type: Easing.OutCubic } }
                Behavior on scale { NumberAnimation { duration: 210; easing.type: Easing.OutCubic } }
                Behavior on opacity { NumberAnimation { duration: 150 } }
                PillShadow { theme: root }

                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    height: 54
                    color: selected ? root.fillHover : root.fillIdle
                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 18
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.kind === "recording" ? "SCREEN RECORDING"
                            : (modelData.kind === "screenshot" ? "SCREENSHOT"
                            : (modelData.kind === "image" ? "IMAGE" : "CLIPBOARD"))
                        color: selected ? root.seal : root.sumi
                        font.family: root.mono
                        font.pixelSize: 9
                        font.letterSpacing: 1.5
                    }
                    Text {
                        anchors.right: parent.right
                        anchors.rightMargin: 18
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.kind === "recording" ? "" : modelData.icon
                        color: selected ? root.seal : root.sumi
                        font.family: root.mono
                        font.pixelSize: 15
                    }
                    Rectangle {
                        id: omakutButton
                        visible: historyCard.selected && modelData.kind === "recording"
                        anchors.right: parent.right
                        anchors.rightMargin: 48
                        anchors.verticalCenter: parent.verticalCenter
                        width: 28
                        height: 28
                        radius: root.tileRadius
                        color: omakutMouse.containsMouse ? root.fillHover : root.fillIdle
                        border.color: root.seal
                        border.width: 1
                        Text {
                            anchors.centerIn: parent
                            text: "✂"
                            color: root.seal
                            font.family: root.mono
                            font.pixelSize: 13
                            font.weight: Font.Bold
                        }
                        ToolTip.visible: omakutMouse.containsMouse
                        ToolTip.text: "Open in Omakut"
                        MouseArea {
                            id: omakutMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: function(mouse) {
                                mouse.accepted = true
                                panel.openRecording(modelData)
                            }
                        }
                    }
                }

                Image {
                    id: cardMedia
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.bottom: cardMeta.top
                    anchors.margins: 16
                    anchors.topMargin: 70
                    visible: historyCard.visible && (modelData.kind === "image"
                        || modelData.kind === "screenshot" || modelData.kind === "recording")
                    source: visible ? panel.imageSource(modelData) : ""
                    sourceSize.width: 512
                    sourceSize.height: 512
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                    cache: true
                }

                Flickable {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.bottom: cardMeta.top
                    anchors.margins: 20
                    anchors.topMargin: 76
                    visible: modelData.kind === "text"
                    clip: true
                    contentWidth: width
                    contentHeight: Math.max(height, cardText.contentHeight)
                    Text {
                        id: cardText
                        width: parent.width
                        text: modelData.fullText
                        color: root.ink
                        font.family: root.mono
                        font.pixelSize: selected ? 13 : 11
                        wrapMode: Text.Wrap
                        textFormat: Text.PlainText
                    }
                }

                Column {
                    anchors.centerIn: parent
                    visible: modelData.kind === "other"
                        || ((modelData.kind === "image" || modelData.kind === "screenshot"
                             || modelData.kind === "recording") && cardMedia.status === Image.Error)
                    spacing: 8
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: modelData.icon
                        color: root.seal
                        font.family: root.mono
                        font.pixelSize: 34
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: modelData.kind === "recording" ? "Preview unavailable" : "Clipboard item"
                        color: root.sumi
                        font.family: root.mono
                        font.pixelSize: 9
                    }
                }

                Column {
                    id: cardMeta
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.margins: 18
                    spacing: 5
                    Text {
                        width: parent.width
                        text: modelData.kind === "image" ? "Copied image" : modelData.label
                        color: root.ink
                        font.family: root.mono
                        font.pixelSize: 11
                        font.weight: Font.Medium
                        maximumLineCount: 2
                        wrapMode: Text.Wrap
                        elide: Text.ElideRight
                    }
                    Text {
                        width: parent.width
                        text: modelData.timestamp || modelData.detail
                        color: root.sumi
                        font.family: root.mono
                        font.pixelSize: 8
                        elide: Text.ElideRight
                    }
                }

                HoverHandler {
                    cursorShape: Qt.PointingHandCursor
                }
                TapHandler {
                    acceptedButtons: Qt.LeftButton
                    onTapped: panel.setSelection(index)
                    onDoubleTapped: panel.activate(index)
                }
            }
        }

        Text {
            anchors.centerIn: parent
            visible: panel.visibleItems.length === 0
            text: panel.items.length === 0 ? "History is empty" : "No matches"
            color: root.ink
            font.family: root.mono
            font.pixelSize: 14
        }

        WheelHandler {
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: function(event) {
                if (event.angleDelta.y < 0) panel.setSelection(panel.selectedIndex + 1)
                else if (event.angleDelta.y > 0) panel.setSelection(panel.selectedIndex - 1)
                event.accepted = true
            }
        }
    }

    Process {
        id: queryProc
        command: ["jq", "-c", ".", panel.historyPath]
        stdout: StdioCollector { onStreamFinished: panel.parse(this.text) }
    }
    Process {
        id: screenshotProc
        command: ["bash", "-c", [
            "D=\"${OMARCHY_SCREENSHOT_DIR:-${XDG_PICTURES_DIR:-$(xdg-user-dir PICTURES 2>/dev/null)}}\";",
            "case \"$D\" in \"\"|\"$HOME\") D=\"$HOME/Pictures\";; esac;",
            "find \"$D\" -maxdepth 1 -type f -iname 'screenshot-*.png'",
            "-printf '%T@\\t%p\\n' 2>/dev/null | sort -rn | head -120"
        ].join(" ")]
        stdout: StdioCollector { waitForEnd: true; onStreamFinished: panel.parseScreenshots(this.text) }
    }
    Process {
        id: recordingProc
        command: ["bash", "-c", [
            "D=\"${OMARCHY_SCREENRECORD_DIR:-${XDG_VIDEOS_DIR:-$(xdg-user-dir VIDEOS 2>/dev/null)}}\";",
            "case \"$D\" in \"\"|\"$HOME\") D=\"$HOME/Videos\";; esac;",
            "C=\"$HOME/.cache/quickshell-history-thumbs\"; mkdir -p \"$C\";",
            "find \"$D\" -maxdepth 1 -type f",
            "\\( -iname 'screenrecording-*.mp4' -o -iname 'screenrecording-*.mkv'",
            "-o -iname 'screenrecording-*.webm' -o -iname 'screenrecording-*.mov' \\)",
            "-printf '%T@\\t%p\\n' 2>/dev/null | sort -rn | head -24 |",
            "while IFS=$'\\t' read -r ts f; do",
            "b=$(basename \"$f\"); o=\"$C/${b%.*}.jpg\";",
            "if [ ! -f \"$o\" ] && command -v ffmpegthumbnailer >/dev/null 2>&1; then",
            "ffmpegthumbnailer -i \"$f\" -o \"$o\" -s 640 -q 7 >/dev/null 2>&1 || true; fi;",
            "printf '%s\\t%s\\n' \"$ts\" \"$f\";",
            "done"
        ].join(" ")]
        stdout: StdioCollector { waitForEnd: true; onStreamFinished: panel.parseRecordings(this.text) }
    }
    Process { id: copyProc }
    Process { id: removeProc; onExited: function(code) { if (code === 0) panel.refresh() } }
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
