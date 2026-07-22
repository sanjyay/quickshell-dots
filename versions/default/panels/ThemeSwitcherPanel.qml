import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../models/ThemeSwitcherModel.js" as ThemeModel
import "../modules"

PanelWindow {
    id: panel
    required property var root

    screen: root.activePopupScreen
    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-theme-switcher"
    WlrLayershell.keyboardFocus: panel.visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    mask: Region { item: card }

    property real reveal: root.themeSwitcherVisible ? 1 : 0
    Behavior on reveal { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
    visible: reveal > 0.001

    property var themes: []
    property string currentId: ""
    property string lastSuccessfulId: ""
    property int selectedIndex: -1
    property string applyingId: ""
    property string sessionStartId: ""
    property bool applyInFlight: false
    property bool rollbackInFlight: false
    property bool cancelInFlight: false
    property bool suppressApply: true
    property bool refreshComplete: false
    property string typeAheadQuery: ""
    property bool cacheListFinished: false
    property string cacheListText: ""
    property bool cacheCurrentFinished: false
    property string cacheCurrentText: ""

    readonly property int topInset: root.barPosition === "top" ? 43 : 8
    readonly property int bottomInset: root.barPosition === "bottom" ? 43 : 8
    readonly property int panelWidth: Math.max(1, width - 48)
    readonly property int usableHeight: Math.max(1, height - topInset - bottomInset)
    readonly property int previewWidth: Math.max(1, Math.min(680, panelWidth, Math.floor((usableHeight - 86) * 16 / 9)))
    readonly property int previewHeight: Math.round(previewWidth * 9 / 16)
    readonly property int sideSpan: Math.max(0, (panelWidth - previewWidth) / 2 - 12)
    readonly property int sideCapacity: Math.max(0, Math.floor(sideSpan / (144 + 12)))
    readonly property int neighbourCount: Math.min(Math.max(0, themes.length - 1), sideCapacity * 2)
    readonly property int panelHeight: Math.min(usableHeight, previewHeight + 70)

    function refresh() {
        // Keep the last valid model visible while the asynchronous discovery
        // pass runs.  Opening the panel must never expose an empty transition.
        if (listProc.running || currentProc.running) return
        currentProcFinished = false
        listProcFinished = false
        currentProc.running = true
        listProc.running = true
    }

    function beginSession() {
        sessionStartId = currentId || cacheCurrentText || lastSuccessfulId
        focusItem.focus = true
        focusItem.forceActiveFocus()
    }

    function themeIds(list) {
        var ids = []
        for (var i = 0; i < list.length; i++) ids.push(list[i].id)
        return ids.join("\n")
    }

    function applyModel(parsed, activeId) {
        if (!parsed.length) return
        var selectedId = selectedTheme() ? selectedTheme().id : ""
        var nextSignature = panel.themeIds(parsed)
        var oldSignature = panel.themeIds(panel.themes)
        if (nextSignature === oldSignature && panel.themes.length > 0) {
            var sameIndex = ThemeModel.indexForId(parsed, selectedId)
            if (sameIndex >= 0) selectedIndex = sameIndex
            currentId = String(activeId || "").trim()
            lastSuccessfulId = currentId || lastSuccessfulId
            refreshComplete = true
            return
        }

        suppressApply = true
        themes = parsed
        currentId = String(activeId || "").trim()
        var nextIndex = ThemeModel.indexForId(parsed, selectedId)
        if (nextIndex < 0) nextIndex = ThemeModel.currentIndex(parsed, currentId)
        selectedIndex = nextIndex
        lastSuccessfulId = currentId
        if (!lastSuccessfulId && selectedIndex >= 0) lastSuccessfulId = parsed[selectedIndex].id
        suppressApply = false
        refreshComplete = true
    }

    function refreshIfChanged(text) {
        var next = ThemeModel.parseRows(text)
        panel.applyModel(next, currentId)
    }

    function finishRefresh() {
        if (!currentProcFinished || !listProcFinished) return
        var parsed = ThemeModel.parseRows(listText)
        panel.applyModel(parsed, currentText)
        focusItem.forceActiveFocus()
    }

    function finishCacheLoad() {
        if (!cacheListFinished || !cacheCurrentFinished) return
        panel.applyModel(ThemeModel.parseRows(cacheListText), cacheCurrentText)
        if (panel.themes.length > 0) focusItem.forceActiveFocus()
    }

    function cardY() {
        return Math.round(Math.max(topInset,
            Math.min(height - bottomInset - panelHeight, (height - panelHeight) / 2)))
    }

    function select(index) {
        if (themes.length === 0) return
        selectedIndex = Math.max(0, Math.min(themes.length - 1, index))
    }

    function move(delta) { select(selectedIndex + delta) }

    function selectedTheme() {
        return selectedIndex >= 0 && selectedIndex < themes.length ? themes[selectedIndex] : null
    }

    function selectTypeAhead(character) {
        if (!themes.length) return
        var query = (typeAheadQuery + character).toLowerCase()
        var found = -1
        for (var i = 0; i < themes.length; i++) {
            if (themes[i].label.toLowerCase().indexOf(query) === 0) { found = i; break }
        }
        if (found < 0) {
            query = character.toLowerCase()
            for (var j = 0; j < themes.length; j++) {
                if (themes[j].label.toLowerCase().indexOf(query) === 0) { found = j; break }
            }
        }
        typeAheadQuery = query
        typeAheadTimer.restart()
        if (found >= 0) select(found)
    }

    function requestApply() {
        if (suppressApply || !refreshComplete || !themes.length || selectedIndex < 0) return
        applyTimer.restart()
    }

    function applyLatest() {
        var item = selectedTheme()
        if (!item || !ThemeModel.validId(item.id)) return
        if (applyInFlight || rollbackInFlight) return
        if (item.id === lastSuccessfulId) return
        applyingId = item.id
        applyInFlight = true
        applyProc.command = ["omarchy-theme-set", item.id]
        applyProc.running = false
        applyProc.running = true
    }

    function confirmAndClose() {
        if (!panel.visible) return
        applyTimer.stop()
        panel.applyLatest()
        root.themeSwitcherVisible = false
    }

    function cancelAndClose() {
        if (!panel.visible) return
        applyTimer.stop()
        typeAheadTimer.stop()
        if (ThemeModel.validId(sessionStartId)) {
            cancelInFlight = true
            cancelProc.command = ["omarchy-theme-set", sessionStartId]
            cancelProc.running = false
            cancelProc.running = true
        }
        restoreSelection(sessionStartId)
        root.themeSwitcherVisible = false
    }

    function handleKey(event) {
        if (event.key === Qt.Key_Escape) {
            panel.cancelAndClose()
            event.accepted = true
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            panel.confirmAndClose()
            event.accepted = true
        } else if (event.key === Qt.Key_Left || event.key === Qt.Key_Up) {
            panel.move(-1); event.accepted = true
        } else if (event.key === Qt.Key_Right || event.key === Qt.Key_Down) {
            panel.move(1); event.accepted = true
        } else if (event.key === Qt.Key_Home) {
            panel.select(0); event.accepted = true
        } else if (event.key === Qt.Key_End) {
            panel.select(panel.themes.length - 1); event.accepted = true
        } else if (event.text && event.text.length === 1
                   && event.text.charCodeAt(0) >= 32) {
            panel.selectTypeAhead(event.text); event.accepted = true
        }
    }

    function notifyFailure() {
        var kept = lastSuccessfulId || "the previous theme"
        console.warn("ThemeSwitcher: theme application failed; kept " + kept)
        Quickshell.execDetached(["notify-send", "Theme switch failed", "Kept " + kept])
    }

    function restoreSelection(id) {
        suppressApply = true
        for (var i = 0; i < themes.length; i++) {
            if (themes[i].id === id) { selectedIndex = i; break }
        }
        suppressApply = false
    }

    Timer {
        id: applyTimer
        interval: 160
        repeat: false
        onTriggered: panel.applyLatest()
    }

    Timer {
        id: typeAheadTimer
        interval: 900
        repeat: false
        onTriggered: panel.typeAheadQuery = ""
    }

    Timer {
        id: scanTimer
        interval: 2500
        repeat: true
        onTriggered: {
            if (!panel.visible || listProc.running || watchListProc.running) return
            watchListProc.running = true
        }
    }

    property bool currentProcFinished: false
    property bool listProcFinished: false
    property string currentText: ""
    property string listText: ""

    Process {
        id: cacheListProc
        command: ["qs-theme-switcher", "cache"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                panel.cacheListText = String(this.text || "")
                panel.cacheListFinished = true
                panel.finishCacheLoad()
            }
        }
    }

    Process {
        id: cacheCurrentProc
        command: ["qs-theme-switcher", "current"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                panel.cacheCurrentText = String(this.text || "").trim()
                panel.cacheCurrentFinished = true
                panel.finishCacheLoad()
            }
        }
    }

    Process {
        id: currentProc
        command: ["qs-theme-switcher", "current"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                panel.currentText = String(this.text || "").trim()
                panel.currentProcFinished = true
                panel.finishRefresh()
            }
        }
        onExited: function(code) {
            if (code !== 0) panel.currentProcFinished = true
            panel.finishRefresh()
        }
    }

    Process {
        id: listProc
        command: ["qs-theme-switcher", "list"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                panel.listText = String(this.text || "")
                panel.listProcFinished = true
                panel.finishRefresh()
            }
        }
        onExited: function(code) {
            if (code !== 0) panel.listProcFinished = true
            panel.finishRefresh()
        }
    }

    Process {
        id: watchListProc
        command: ["qs-theme-switcher", "list"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: panel.refreshIfChanged(String(this.text || ""))
        }
    }

    Process {
        id: applyProc
        command: []
        running: false
        onExited: function(code) {
            panel.applyInFlight = false
            if (panel.cancelInFlight) return
            if (code === 0) {
                panel.lastSuccessfulId = panel.applyingId
                panel.currentId = panel.applyingId
                panel.root.reloadThemePalette()
            } else if (ThemeModel.validId(panel.lastSuccessfulId)) {
                panel.rollbackInFlight = true
                rollbackProc.command = ["omarchy-theme-set", panel.lastSuccessfulId]
                rollbackProc.running = false
                rollbackProc.running = true
            } else {
                panel.notifyFailure()
            }
            if (!panel.applyInFlight && !panel.rollbackInFlight && panel.selectedTheme()
                    && panel.selectedTheme().id !== panel.lastSuccessfulId)
                applyTimer.restart()
        }
    }

    Process {
        id: rollbackProc
        command: []
        running: false
        onExited: function(code) {
            panel.rollbackInFlight = false
            panel.restoreSelection(panel.lastSuccessfulId)
            panel.root.reloadThemePalette()
            panel.notifyFailure()
            if (code !== 0)
                console.warn("ThemeSwitcher: rollback failed with code " + code)
        }
    }

    Process {
        id: cancelProc
        command: []
        running: false
        onExited: function(code) {
            panel.cancelInFlight = false
            if (code === 0) {
                panel.lastSuccessfulId = panel.sessionStartId
                panel.currentId = panel.sessionStartId
                panel.root.reloadThemePalette()
            } else {
                console.warn("ThemeSwitcher: cancel restore failed with code " + code)
            }
        }
    }

    Rectangle {
        id: blurSurface
        anchors.fill: parent
        color: Qt.rgba(root.paper.r, root.paper.g, root.paper.b, 0.10)
        opacity: panel.reveal
    }

    Item {
        id: focusItem
        anchors.fill: parent
        focus: panel.visible
        Keys.priority: Keys.BeforeItem
        Keys.onPressed: function(event) { panel.handleKey(event) }
    }

    Item {
        id: card
        x: Math.round((parent.width - width) / 2)
        y: panel.cardY()
        width: panel.panelWidth
        height: panel.panelHeight

        Repeater {
            model: panel.themes
            delegate: Item {
                required property var modelData
                required property int index
                readonly property int distance: index - panel.selectedIndex
                readonly property int rank: Math.abs(distance)
                readonly property bool shown: distance === 0 || (rank <= panel.sideCapacity
                    && rank <= panel.neighbourCount)
                readonly property real sideWidth: panel.sideCapacity > 0 ? panel.sideSpan / panel.sideCapacity : 0
                width: panel.previewWidth
                height: panel.previewHeight + 38
                x: Math.round(card.width / 2 - width / 2 + (distance === 0 ? 0 : (distance < 0 ? -1 : 1) * (panel.previewWidth / 2 + 12 + sideWidth * (rank - 0.5))))
                y: Math.round((card.height - height) / 2)
                z: 100 - rank
                visible: shown
                opacity: shown ? Math.max(0.28, 1 - rank * 0.18) : 0
                scale: distance === 0 ? 1 : Math.max(144 / panel.previewWidth, 0.78 - (rank - 1) * 0.12)
                Behavior on x { enabled: panel.root.themeSwitcherVisible; NumberAnimation { duration: 210; easing.type: Easing.OutCubic } }
                Behavior on opacity { enabled: panel.root.themeSwitcherVisible; NumberAnimation { duration: 210 } }
                Behavior on scale { enabled: panel.root.themeSwitcherVisible; NumberAnimation { duration: 210; easing.type: Easing.OutCubic } }

                transform: Rotation {
                    origin.x: width / 2
                    origin.y: panel.previewHeight / 2
                    axis { x: 0; y: 1; z: 0 }
                    angle: distance === 0 ? 0 : (distance < 0 ? 13 : -13)
                    Behavior on angle {
                        enabled: panel.root.themeSwitcherVisible
                        NumberAnimation { duration: 210 }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: panel.previewHeight
                    radius: root.pillRadius
                    color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.08)
                    border.color: index === panel.selectedIndex ? root.seal : root.pillBorder
                    border.width: index === panel.selectedIndex ? 2 : root.pillBorderW
                    clip: true
                    Image {
                        anchors.fill: parent
                        source: "file://" + modelData.preview
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        cache: true
                        smooth: true
                    }
                }

                Text {
                    anchors.top: parent.top
                    anchors.topMargin: panel.previewHeight + 10
                    width: parent.width
                    text: modelData.label
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    color: index === panel.selectedIndex ? root.ink : root.sumi
                    style: Text.Outline
                    styleColor: root.paper
                    font.family: root.mono
                    font.pixelSize: root.menuFontSize
                    font.weight: index === panel.selectedIndex ? Font.DemiBold : Font.Normal
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: {
                        panel.select(index)
                    }
                    onDoubleClicked: {
                        panel.select(index)
                        panel.confirmAndClose()
                    }
                    onWheel: function(event) {
                        panel.move(event.angleDelta.y < 0 ? 1 : -1)
                        event.accepted = true
                    }
                }
            }
        }
    }

    onSelectedIndexChanged: panel.requestApply()
    onVisibleChanged: {
        if (visible) {
            panel.beginSession()
            panel.refresh()
            scanTimer.start()
            focusItem.forceActiveFocus()
        } else {
            applyTimer.stop()
            typeAheadTimer.stop()
            scanTimer.stop()
            watchListProc.running = false
            focusItem.focus = false
        }
    }

    Component.onCompleted: panel.refresh()
}
