import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../modules"
import "HistoryModel.js" as HistoryModel

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
    property int insertionSequence: 0
    property double historyFileMtimeMs: 0
    property double lastRefreshAtMs: 0
    property string modelSignature: ""
    property string screenshotWatchSignature: ""
    property string lastErrorCode: ""
    property var previewById: ({})
    property var previewAttemptsById: ({})
    property string previewJobId: ""
    property string previewJobPath: ""
    property string previewJobOutput: ""
    property int previewRetryCount: 0
    readonly property string previewHelperPath: Qt.resolvedUrl("../../../scripts/history-recording-preview.sh").toString().replace(/^file:\/\//, "")
    readonly property int previewJobsRunning: previewProc.running ? 1 : 0
    readonly property string historyPath: Quickshell.env("HOME")
        + "/.local/state/omarchy/clipboard-history.json"
    readonly property bool inputDebug: Quickshell.env("QS_CLIPBOARD_INPUT_DEBUG") === "1"
    readonly property var visibleItems: filteredItems()
    readonly property int fanStartIndex: Math.max(0, Math.min(selectedIndex - 4,
        Math.max(0, visibleItems.length - 9)))
    readonly property var fanItems: visibleItems.slice(fanStartIndex,
        Math.min(visibleItems.length, fanStartIndex + 9))
    readonly property var selectedItem: visibleItems.length > 0
        ? visibleItems[Math.max(0, Math.min(selectedIndex, visibleItems.length - 1))] : null

    Component.onCompleted: root.historyDiagnosticsProvider = panel
    Component.onDestruction: if (root.historyDiagnosticsProvider === panel) root.historyDiagnosticsProvider = null

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
        if (queryProc.running) historyChangeTimer.restart()
        else queryProc.running = true
        screenshotProc.running = false
        screenshotProc.running = true
        recordingProc.running = false
        recordingProc.running = true
    }

    function refreshRecordings() {
        recordingsLoaded = false
        recordingProc.running = false
        recordingProc.running = true
    }

    function retryPreview(row) {
        if (!row || row.type !== "recording" || row.previewState !== "permanent-failure") return
        var states = Object.assign({}, previewById)
        var attempts = Object.assign({}, previewAttemptsById)
        states[row.id] = { state: "not-requested", path: row.previewPath,
            completedAtMs: row.eventCompletedAtMs }
        delete attempts[row.id]
        previewById = states
        previewAttemptsById = attempts
        refresh()
    }

    function imageSource(item) {
        if (!item || (item.kind !== "image" && item.kind !== "screenshot" && item.kind !== "recording") || !item.imagePath) return ""
        if (item.imagePath.indexOf("file://") === 0) return item.imagePath
        return "file://" + encodeURI(item.imagePath) + (item.previewState === "ready" ? "?v=" + item.eventCompletedAtMs : "")
    }

    function textEntropy(value) {
        var counts = {}
        for (var i = 0; i < value.length; i++) counts[value[i]] = (counts[value[i]] || 0) + 1
        var entropy = 0
        Object.keys(counts).forEach(function(key) {
            var probability = counts[key] / value.length
            entropy -= probability * Math.log(probability) / Math.log(2)
        })
        return entropy
    }

    function isSensitiveClipboardText(text) {
        var value = String(text || "").trim()
        if (!value) return false
        var currentUser = String(Quickshell.env("USER") || "").trim().toLowerCase()
        if (currentUser && value.toLowerCase() === currentUser) return true
        if (/\b[a-z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-z0-9-]+(?:\.[a-z0-9-]+)+\b/i.test(value)) return true
        if (/\b(?:password|passwd|passphrase|pwd|username|user\s*name|login|account\s*(?:id|name)|auth(?:entication)?\s*token|access[_ -]?token|refresh[_ -]?token|bearer|api[_ -]?key|client[_ -]?secret|secret|otp|one[_ -]?time[_ -]?(?:password|code)|verification[_ -]?code|recovery[_ -]?code)\b\s*(?:=|:|is)\s*\S{3,}/i.test(value)) return true
        if (/-----BEGIN (?:[A-Z0-9 ]+ )?PRIVATE KEY-----/.test(value)) return true
        if (/^\s*(?:authorization|proxy-authorization)\s*:\s*\S+/im.test(value)) return true
        if (/\b[a-z][a-z0-9+.-]*:\/\/[^\s/:]+:[^\s/@]+@/i.test(value)) return true
        if (/\beyJ[A-Za-z0-9_-]{5,}\.[A-Za-z0-9_-]{5,}\.[A-Za-z0-9_-]{5,}\b/.test(value)) return true
        if (/\b(?:gh[pousr]_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}|glpat-[A-Za-z0-9_-]{20,}|sk-(?:proj-)?[A-Za-z0-9_-]{20,}|xox[baprs]-[A-Za-z0-9-]{10,}|AKIA[0-9A-Z]{16})\b/.test(value)) return true
        if (/^\d{4,8}$/.test(value)) return true
        if (/^[A-Za-z0-9_+/.=-]{20,}$/.test(value)) {
            var classes = (/[a-z]/.test(value) ? 1 : 0) + (/[A-Z]/.test(value) ? 1 : 0)
                + (/\d/.test(value) ? 1 : 0) + (/[^A-Za-z0-9]/.test(value) ? 1 : 0)
            if (classes >= 3 && textEntropy(value) >= 3.5) return true
        }
        return false
    }

    function finishRefresh() {
        if (!clipboardLoaded || !screenshotsLoaded || !recordingsLoaded) return
        var screenshotsBySecond = {}
        screenshotItems.forEach(function(item) { screenshotsBySecond[Math.floor(item.sortTimestampMs / 1000)] = true })
        var uniqueClipboardItems = clipboardItems.filter(function(item) {
            return item.kind !== "image" || !screenshotsBySecond[Math.floor(item.sortTimestampMs / 1000)]
        })
        var merged = HistoryModel.reconcile(items, recordingItems.concat(screenshotItems, uniqueClipboardItems))
        var sorted = HistoryModel.sorted(merged)
        var signature = sorted.map(function(row) {
            return row.id + ":" + row.sortTimestampMs + ":" + row.state + ":" + row.previewState
        }).join("|")
        if (signature !== modelSignature) {
            modelSignature = signature
            items = sorted
        }
        lastRefreshAtMs = Date.now()
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
        Qt.callLater(panel.requestNextPreview)
    }

    function requestNextPreview() {
        if (previewProc.running) return
        for (var i = 0; i < items.length; i++) {
            var row = items[i]
            if (row.type !== "recording" || row.state !== "recording-complete"
                    || row.previewState === "ready" || row.previewState === "generating"
                    || row.previewState === "permanent-failure"
                    || !row.sourcePath) continue
            previewJobId = row.id
            previewJobPath = row.sourcePath
            var output = row.previewPath
            previewJobOutput = output
            var states = Object.assign({}, previewById)
            states[row.id] = { state: "generating", path: output, completedAtMs: row.eventCompletedAtMs }
            previewById = states
            previewProc.command = [previewHelperPath, row.sourcePath, output]
            previewProc.running = true
            refreshRecordings()
            return
        }
    }

    function diagnosticsObject() {
        var sanitized = []
        var recordingCount = 0
        var activeCount = 0
        var valid = true
        for (var i = 0; i < items.length; i++) {
            var row = items[i]
            if (row.type === "recording") recordingCount++
            if (row.state === "recording-active" || row.state === "recording-finalizing") activeCount++
            if (i > 0 && HistoryModel.compare(items[i - 1], row) > 0) valid = false
            sanitized.push({ type: row.type, sortTimestampMs: row.sortTimestampMs,
                index: i, state: row.state, previewState: row.previewState })
        }
        return { eventCount: items.length, recordingCount: recordingCount,
            activeRecordingCount: activeCount, latestEvent: sanitized.length ? sanitized[0] : null,
            orderingValid: valid, previewJobsRunning: previewJobsRunning,
            previewRetryCount: previewRetryCount, watcherActive: liveRefreshTimer.running,
            lastRefreshAt: lastRefreshAtMs > 0 ? new Date(lastRefreshAtMs).toISOString() : null,
            lastErrorCode: lastErrorCode || null, ordering: sanitized }
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

    function parse(text, fileMtimeMs) {
        try {
            var payload = JSON.parse(String(text || "{}"))
            var raw = Array.isArray(payload) ? payload : (Array.isArray(payload.data) ? payload.data : [])
            historyFileMtimeMs = HistoryModel.finiteMs(fileMtimeMs || payload.mtimeMs || historyFileMtimeMs || Date.now())
            if (!Array.isArray(raw)) raw = []

            var out = []
            for (var i = 0; i < raw.length; i++) {
                var x = raw[i] || {}
                var previewType = String(x.type || "").toLowerCase()
                var isImage = previewType === "image" && !!x.path
                var isText = previewType === "text" && typeof x.text === "string"
                var fullText = isText ? String(x.text || "") : ""
                if (isText && isSensitiveClipboardText(fullText)) continue
                var mimeType = String(x.mime || "")
                var timestamp = String(x.capturedAt || "")
                var parsedTimestamp = Date.parse(timestamp)
                // Quattro's native store is newest-first but most text entries
                // have no timestamp. Give that ordering realistic separation so
                // real screenshot/recording mtimes are not buried behind it.
                var parsedMs = isNaN(parsedTimestamp) ? 0 : parsedTimestamp
                // Native text history has no per-entry timestamp. Anchor its
                // newest-first order to the history file mtime, with enough
                // separation that hundreds of legacy rows do not masquerade
                // as events from the same second and bury real media events.
                var eventTimeMs = HistoryModel.finiteMs(parsedMs) || Math.max(1, historyFileMtimeMs - i * 60000)
                var label = isImage ? "Image clipboard entry"
                    : (fullText ? fullText.replace(/\s+/g, " ").trim().slice(0, 120) : "Clipboard entry")
                var metadata = [timestamp, mimeType].filter(function(value) { return value.length > 0 }).join(" · ")
                out.push(HistoryModel.event({
                    id: "native:" + i + ":" + eventTimeMs,
                    type: isImage ? "image" : (isText ? "text" : "other"),
                    entryType: previewType || "other",
                    source: "omarchy-clipboard",
                    sourcePath: isImage ? String(x.path || "") : "",
                    eventStartedAtMs: eventTimeMs,
                    eventCompletedAtMs: eventTimeMs,
                    sortTimestampMs: eventTimeMs,
                    insertionSequence: raw.length - i,
                    state: "complete",
                    previewState: isImage ? "ready" : "not-requested",
                    previewPath: isImage ? String(x.path || "") : "",
                    title: label,
                    subtitle: metadata || String(x.provider || "clipboard"),
                    fullText: fullText,
                    previewText: isText ? fullText : "",
                    mimeType: mimeType,
                    nativeHistoryIndex: i,
                    timestamp: timestamp,
                    timestampFallback: parsedMs > 0 ? "" : "history-file-mtime-plus-native-order",
                    searchKeywords: (label + " " + fullText + " " + metadata + " " + mimeType + " " + previewType).toLowerCase(),
                    icon: isImage ? "" : (isText ? "" : "󰋼")
                }))
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
            var eventTimeMs = HistoryModel.finiteMs(fields.shift())
            var size = Number(fields.shift()) || 0
            var mediaState = fields.shift() || "complete"
            var path = fields.join("\t").trim()
            if (!path) continue
            var name = path.split("/").pop()
            var stem = name.replace(/\.[^.]+$/, "")
            var prefix = kind === "recording" ? /^screenrecording-/ : /^screenshot-/
            var stamp = stem.replace(prefix, "").replace("_", "  ")
            var captureTimeMs = kind === "recording" ? HistoryModel.recordingStartMs(name) : 0
            var startedAtMs = captureTimeMs || eventTimeMs
            var id = HistoryModel.eventId(kind, path, startedAtMs)
            var preview = previewById[id] || {}
            var completed = mediaState === "active" ? 0 : eventTimeMs
            var previewPath = kind === "recording"
                ? Quickshell.env("HOME") + "/.cache/quickshell-history-thumbs/" + stem + ".jpg" : path
            var previewState = kind === "recording"
                ? (mediaState === "active" ? "waiting-for-final-file" : String(preview.state || "not-requested")) : "ready"
            out.push(HistoryModel.event({
                id: id,
                type: kind,
                entryType: kind,
                source: kind === "recording" ? "omarchy-screenrecord" : "omarchy-screenshot",
                sourcePath: path,
                eventStartedAtMs: startedAtMs,
                eventCompletedAtMs: completed,
                sortTimestampMs: startedAtMs,
                insertionSequence: ++insertionSequence,
                state: kind === "recording" ? (mediaState === "active" ? "recording-active" : "recording-complete") : "complete",
                previewState: previewState,
                previewPath: previewPath,
                title: stem.replace(prefix, kind === "recording" ? "Screen recording · " : "Screenshot · "),
                subtitle: stamp,
                fullText: "",
                previewText: "",
                mimeType: kind === "recording" ? "video" : "image/png",
                timestamp: stamp,
                timestampFallback: captureTimeMs > 0 ? "" : "file-mtime",
                searchKeywords: (name + " " + (kind === "recording" ? "screen recording video " : "screenshot image ") + stamp).toLowerCase(),
                icon: kind === "recording" ? "" : ""
            }))
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
    Timer {
        id: liveRefreshTimer
        interval: panel.recordingItems.some(function(row) { return row.state === "recording-active" }) ? 750 : 2000
        repeat: true
        running: panel.visible
        onTriggered: {
            panel.refreshRecordings()
            if (!screenshotWatchProc.running) screenshotWatchProc.running = true
        }
    }
    Timer {
        id: historyChangeTimer
        interval: 80
        repeat: false
        onTriggered: {
            if (queryProc.running) {
                restart()
                return
            }
            queryProc.running = true
        }
    }
    Timer { id: previewRetryTimer; interval: 1000; repeat: false; onTriggered: panel.requestNextPreview() }

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
        readonly property real cardHeight: Math.min(430, panel.height * 0.62)
        readonly property real searchOffset: panel.query.length > 0 ? 44 : 0
        readonly property real selectedCardTop: (height - cardHeight) / 2 - 12
            + searchOffset - cardHeight * 0.08
        Keys.priority: Keys.BeforeItem
        Keys.onPressed: function(event) { panel.handleKey(event) }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            y: Math.max(12, fanFocus.selectedCardTop - implicitHeight - 10)
            z: 40
            visible: panel.query.length > 0
            text: panel.query
            color: root.ink
            font.family: root.mono
            font.pixelSize: 16
            font.letterSpacing: 0.5
            opacity: 0.82
        }

        Repeater {
            model: panel.fanItems
            delegate: Rectangle {
                id: historyCard
                required property int index
                required property var modelData
                readonly property int absoluteIndex: panel.fanStartIndex + index
                readonly property int relativeIndex: absoluteIndex - panel.selectedIndex
                readonly property int distance: Math.abs(relativeIndex)
                readonly property bool selected: relativeIndex === 0

                visible: distance <= 4
                width: Math.min(330, panel.width * 0.28)
                height: Math.min(430, panel.height * 0.62)
                x: Math.round((panel.width - width) / 2 + relativeIndex * Math.min(132, panel.width * 0.11))
                y: Math.round((panel.height - height) / 2 + distance * 24
                    + (selected ? -12 : 10) + fanFocus.searchOffset)
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
                        || modelData.kind === "screenshot"
                        || (modelData.kind === "recording" && modelData.previewState === "ready"))
                    source: visible ? panel.imageSource(modelData) : ""
                    sourceSize.width: 512
                    sourceSize.height: 512
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                    cache: false
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
                        || (modelData.kind === "recording" && modelData.previewState !== "ready")
                        || ((modelData.kind === "image" || modelData.kind === "screenshot")
                            && cardMedia.status === Image.Error)
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
                        text: modelData.kind !== "recording" ? "Clipboard item"
                            : (modelData.state === "recording-active" ? "Recording in progress"
                            : (modelData.previewState === "generating" ? "Generating preview…"
                            : (modelData.previewState === "retryable-failure" ? "Preview retry scheduled"
                            : (modelData.previewState === "permanent-failure" ? "Preview unavailable · double-click to retry"
                            : "Finalizing recording…"))))
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
                    onTapped: panel.setSelection(historyCard.absoluteIndex)
                    onDoubleTapped: {
                        if (modelData.kind === "recording" && modelData.previewState === "permanent-failure")
                            panel.retryPreview(modelData)
                        else panel.activate(historyCard.absoluteIndex)
                    }
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
        command: ["bash", "-c", [
            "p=\"$1\"; m=$(stat -c %Y -- \"$p\" 2>/dev/null || echo 0);",
            "jq -c --argjson mtimeMs \"$((m * 1000))\"",
            "'{mtimeMs:$mtimeMs,data:(if type == \"array\" then .[0:120] else [] end)}' \"$p\""
        ].join(" "), "history-query", panel.historyPath]
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: panel.parse(this.text)
        }
    }
    FileView {
        id: historyFileWatcher
        path: panel.historyPath
        watchChanges: true
        onFileChanged: {
            reload()
            if (panel.visible) historyChangeTimer.restart()
        }
    }
    Process {
        id: screenshotWatchProc
        command: ["bash", "-c", [
            "D=\"${OMARCHY_SCREENSHOT_DIR:-${XDG_PICTURES_DIR:-$(xdg-user-dir PICTURES 2>/dev/null)}}\";",
            "case \"$D\" in \"\"|\"$HOME\") D=\"$HOME/Pictures\";; esac; stat -c %y -- \"$D\" 2>/dev/null || true"
        ].join(" ")]
        stdout: StdioCollector {
            onStreamFinished: {
                var next = this.text.trim()
                if (panel.screenshotWatchSignature && next && next !== panel.screenshotWatchSignature && !screenshotProc.running)
                    screenshotProc.running = true
                panel.screenshotWatchSignature = next
            }
        }
    }
    Process {
        id: screenshotProc
        command: ["bash", "-c", [
            "D=\"${OMARCHY_SCREENSHOT_DIR:-${XDG_PICTURES_DIR:-$(xdg-user-dir PICTURES 2>/dev/null)}}\";",
            "case \"$D\" in \"\"|\"$HOME\") D=\"$HOME/Pictures\";; esac;",
            "find \"$D\" -maxdepth 1 -type f -iname 'screenshot-*.png'",
            "-printf '%T@\\t%s\\tcomplete\\t%p\\n' 2>/dev/null | sort -rn | head -120"
        ].join(" ")]
        stdout: StdioCollector { waitForEnd: true; onStreamFinished: panel.parseScreenshots(this.text) }
    }
    Process {
        id: recordingProc
        command: ["bash", "-c", [
            "D=\"${OMARCHY_SCREENRECORD_DIR:-${XDG_VIDEOS_DIR:-$(xdg-user-dir VIDEOS 2>/dev/null)}}\";",
            "case \"$D\" in \"\"|\"$HOME\") D=\"$HOME/Videos\";; esac;",
            "active=; if pgrep -f '^gpu-screen-recorder' >/dev/null 2>&1; then active=$(cat /tmp/omarchy-screenrecord-filename 2>/dev/null || true); fi;",
            "find \"$D\" -maxdepth 1 -type f",
            "\\( -iname 'screenrecording-*.mp4' -o -iname 'screenrecording-*.mkv'",
            "-o -iname 'screenrecording-*.webm' -o -iname 'screenrecording-*.mov' \\)",
            "-printf '%T@\\t%s\\t%p\\n' 2>/dev/null | sort -rn | head -24 |",
            "while IFS=$'\\t' read -r ts size f; do",
            "state=complete; [ -n \"$active\" ] && [ \"$f\" = \"$active\" ] && state=active;",
            "printf '%s\\t%s\\t%s\\t%s\\n' \"$ts\" \"$size\" \"$state\" \"$f\";",
            "done"
        ].join(" ")]
        stdout: StdioCollector { waitForEnd: true; onStreamFinished: panel.parseRecordings(this.text) }
    }
    Process { id: copyProc }
    Process { id: removeProc; onExited: function(code) { if (code === 0) panel.refresh() } }
    Process { id: editProc }
    Process {
        id: previewProc
        onExited: function(code) {
            var states = Object.assign({}, panel.previewById)
            var attempts = Object.assign({}, panel.previewAttemptsById)
            var count = Number(attempts[panel.previewJobId] || 0) + (code === 0 ? 0 : 1)
            attempts[panel.previewJobId] = count
            panel.previewAttemptsById = attempts
            if (code === 0) {
                states[panel.previewJobId] = { state: "ready",
                    path: panel.previewJobOutput, completedAtMs: Date.now() }
                panel.lastErrorCode = ""
            } else {
                panel.previewRetryCount++
                states[panel.previewJobId] = { state: count >= 3 ? "permanent-failure" : "retryable-failure",
                    path: panel.previewJobOutput, completedAtMs: Date.now() }
                panel.lastErrorCode = code === 10 ? "recording-file-unavailable"
                    : (code === 11 ? "recording-not-finalized" : "preview-generation-failed")
            }
            panel.previewById = states
            panel.previewJobId = ""
            panel.previewJobPath = ""
            panel.previewJobOutput = ""
            panel.refreshRecordings()
            if (code !== 0 && count < 3) previewRetryTimer.restart()
        }
    }
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
