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

    property real reveal: root.themeSwitcherVisible ? 1 : 0
    Behavior on reveal { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
    visible: reveal > 0.001

    property var themes: []
    property string currentId: ""
    property string lastSuccessfulId: ""
    property int selectedIndex: -1
    property string applyingId: ""
    property bool applyInFlight: false
    property bool rollbackInFlight: false
    property bool suppressApply: true
    property bool refreshComplete: false
    property string typeAheadQuery: ""
    property bool cacheListFinished: false
    property string cacheListText: ""
    property bool cacheCurrentFinished: false
    property string cacheCurrentText: ""

    readonly property int topInset: root.barPosition === "top" ? 43 : 8
    readonly property int bottomInset: root.barPosition === "bottom" ? 43 : 8
    // The overlay already spans the monitor; use its usable width so the
    // carousel consumes the side space without changing the overlay itself.
    readonly property int cardWidth: Math.max(1, width - 48)
    readonly property int cardHeight: Math.max(1, Math.min(height - topInset - bottomInset,
        Math.max(380, Math.round(height * 0.57))))
    // Keep the focused preview large, but leave enough proportional room for
    // two complete neighbours on each side at common monitor widths.
    readonly property int previewWidth: Math.max(1, Math.min(500,
        Math.max(320, Math.round(cardWidth * 0.42))))
    readonly property int previewHeight: Math.round(previewWidth * 9 / 16)
    readonly property int step: Math.round(Math.max(150, Math.min(400,
        cardWidth / 4 - previewWidth * 0.13)))

    function refresh() {
        // Keep the last valid model visible while the asynchronous discovery
        // pass runs.  Opening the panel must never expose an empty transition.
        if (listProc.running || currentProc.running) return
        currentProcFinished = false
        listProcFinished = false
        currentProc.running = true
        listProc.running = true
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
            Math.min(height - bottomInset - cardHeight, (height - cardHeight) / 2)))
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

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(root.paper.r, root.paper.g, root.paper.b, 0.74)
        opacity: panel.reveal

        MouseArea {
            anchors.fill: parent
            onClicked: root.themeSwitcherVisible = false
            onWheel: function(event) {
                panel.move(event.angleDelta.y < 0 ? 1 : -1)
                event.accepted = true
            }
        }
    }

    Item {
        id: focusItem
        anchors.fill: parent
        focus: panel.visible
        Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Escape) {
                root.themeSwitcherVisible = false
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
    }

    Rectangle {
        id: card
        x: Math.round((parent.width - width) / 2)
        y: panel.cardY()
        width: panel.cardWidth
        height: panel.cardHeight
        radius: root.pillRadius
        color: Qt.rgba(root.paper.r, root.paper.g, root.paper.b, 1)
        border.color: root.pillBorder
        border.width: root.pillBorderW
        clip: true
        PillShadow { theme: root }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
            onClicked: {}
            onWheel: function(event) {
                panel.move(event.angleDelta.y < 0 ? 1 : -1)
                event.accepted = true
            }
        }

        Repeater {
            model: panel.themes
            delegate: Item {
                required property var modelData
                required property int index
                readonly property int distance: index - panel.selectedIndex
                readonly property bool shown: Math.abs(distance) <= 2
                width: panel.previewWidth
                height: panel.previewHeight + 42
                x: Math.round(card.width / 2 + distance * panel.step - width / 2)
                y: Math.round((card.height - height) / 2)
                z: 100 - Math.abs(distance)
                visible: shown
                opacity: shown ? Math.max(0.18, 1 - Math.abs(distance) * 0.22) : 0
                scale: distance === 0 ? 1
                       : (Math.abs(distance) === 1 ? 0.76 : 0.52)
                Behavior on x { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                Behavior on opacity { NumberAnimation { duration: 220 } }
                Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

                transform: Rotation {
                    origin.x: width / 2
                    origin.y: panel.previewHeight / 2
                    axis { x: 0; y: 1; z: 0 }
                    angle: Math.max(-16, Math.min(16, distance * -8))
                    Behavior on angle { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
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
                    anchors.topMargin: panel.previewHeight + 12
                    width: parent.width
                    text: modelData.label
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    color: index === panel.selectedIndex ? root.ink : root.sumi
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
            panel.refresh()
            scanTimer.start()
            focusItem.forceActiveFocus()
        } else {
            applyTimer.stop()
            typeAheadTimer.stop()
            scanTimer.stop()
            watchListProc.running = false
        }
    }

    Component.onCompleted: panel.refresh()
}
