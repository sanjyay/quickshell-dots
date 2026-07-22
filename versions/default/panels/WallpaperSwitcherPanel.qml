import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../models/WallpaperSwitcherModel.js" as WallpaperModel
import "../modules"

PanelWindow {
    id: panel
    required property var root
    screen: root.activePopupScreen
    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-wallpaper-switcher"
    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    mask: Region { item: body }

    property real reveal: root.wallpaperSwitcherVisible ? 1 : 0
    visible: reveal > 0.001
    Behavior on reveal { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
    property var wallpapers: []
    property int selectedIndex: -1
    property string currentPath: ""
    property string lastSuccessfulPath: ""
    property string applyingPath: ""
    property string queuedPath: ""
    property string sessionStartPath: ""
    property bool suppressApply: true
    property bool applyInFlight: false
    property bool cancelInFlight: false
    property bool listFinished: false
    property bool currentFinished: false
    property string listText: ""
    property string currentText: ""

    readonly property int topInset: root.barPosition === "top" ? 43 : 8
    readonly property int bottomInset: root.barPosition === "bottom" ? 43 : 8
    readonly property int panelWidth: Math.max(1, width - 48)
    readonly property int usableHeight: Math.max(1, height - topInset - bottomInset)
    readonly property int previewWidth: Math.max(1, Math.min(680, panelWidth, Math.floor((usableHeight - 86) * 16 / 9)))
    readonly property int previewHeight: Math.round(previewWidth * 9 / 16)
    readonly property int sideSpan: Math.max(0, (panelWidth - previewWidth) / 2 - 12)
    readonly property int sideCapacity: Math.max(0, Math.floor(sideSpan / (144 + 12)))
    readonly property int neighbourCount: Math.min(Math.max(0, wallpapers.length - 1), sideCapacity * 2)
    readonly property int panelHeight: Math.min(usableHeight, previewHeight + 70)

    function refresh() {
        listFinished = false; currentFinished = false
        listProc.running = false; currentProc.running = false
        listProc.running = true; currentProc.running = true
    }
    function beginSession() {
        sessionStartPath = currentPath || lastSuccessfulPath
        focusItem.focus = true
        focusItem.forceActiveFocus()
    }
    function finishRefresh() {
        if (!listFinished || !currentFinished) return
        suppressApply = true
        wallpapers = WallpaperModel.parseRows(listText)
        currentPath = String(currentText || "").trim()
        lastSuccessfulPath = currentPath
        selectedIndex = WallpaperModel.indexForPath(wallpapers, currentPath)
        suppressApply = false
        focusItem.forceActiveFocus()
    }
    function move(delta) {
        if (wallpapers.length) selectedIndex = WallpaperModel.wrapped(selectedIndex + delta, wallpapers.length)
    }
    function requestApply() {
        if (suppressApply || selectedIndex < 0 || selectedIndex >= wallpapers.length) return
        queuedPath = wallpapers[selectedIndex].path
        applyTimer.restart()
    }
    function applyLatest() {
        if (applyInFlight || !queuedPath || queuedPath === lastSuccessfulPath) return
        applyingPath = queuedPath; applyInFlight = true
        applyProc.command = ["omarchy-theme-bg-set", applyingPath]
        applyProc.running = false; applyProc.running = true
    }
    function restoreLast() {
        suppressApply = true
        selectedIndex = WallpaperModel.indexForPath(wallpapers, lastSuccessfulPath)
        suppressApply = false
        Quickshell.execDetached(["notify-send", "Wallpaper switch failed", "Kept the previous wallpaper"])
    }
    function confirmAndClose() {
        if (!panel.visible) return
        applyTimer.stop()
        if (selectedIndex >= 0 && selectedIndex < wallpapers.length)
            queuedPath = wallpapers[selectedIndex].path
        applyLatest()
        root.wallpaperSwitcherVisible = false
    }
    function cancelAndClose() {
        if (!panel.visible) return
        applyTimer.stop()
        queuedPath = ""
        if (sessionStartPath) {
            cancelInFlight = true
            cancelProc.command = ["omarchy-theme-bg-set", sessionStartPath]
            cancelProc.running = false
            cancelProc.running = true
        }
        suppressApply = true
        selectedIndex = WallpaperModel.indexForPath(wallpapers, sessionStartPath)
        suppressApply = false
        root.wallpaperSwitcherVisible = false
    }
    function handleKey(e) {
        if (e.key === Qt.Key_Escape) {
            panel.cancelAndClose(); e.accepted = true
        } else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) {
            panel.confirmAndClose(); e.accepted = true
        } else if (e.key === Qt.Key_Left || e.key === Qt.Key_Up) {
            panel.move(-1); e.accepted = true
        } else if (e.key === Qt.Key_Right || e.key === Qt.Key_Down) {
            panel.move(1); e.accepted = true
        }
    }
    function signedDistance(index) {
        var n = wallpapers.length
        if (n < 2) return 0
        var forward = WallpaperModel.wrapped(index - selectedIndex, n)
        var backward = forward - n
        return Math.abs(forward) <= Math.abs(backward) ? forward : backward
    }

    Timer { id: applyTimer; interval: 160; onTriggered: panel.applyLatest() }
    Process { id: listProc; command: ["qs-wallpaper-switcher", "list"]; stdout: StdioCollector { onStreamFinished: { panel.listText = String(text || ""); panel.listFinished = true; panel.finishRefresh() } } }
    Process { id: currentProc; command: ["qs-wallpaper-switcher", "current"]; stdout: StdioCollector { onStreamFinished: { panel.currentText = String(text || ""); panel.currentFinished = true; panel.finishRefresh() } } }
    Process {
        id: verifyProc; command: ["qs-wallpaper-switcher", "current"]
        stdout: StdioCollector { onStreamFinished: {
            if (panel.cancelInFlight) {
                panel.applyInFlight = false
                return
            }
            var actual = String(text || "").trim()
            if (actual === panel.applyingPath) { panel.lastSuccessfulPath = actual; panel.currentPath = actual }
            else panel.restoreLast()
            panel.applyInFlight = false
            if (panel.queuedPath !== panel.lastSuccessfulPath) panel.applyTimer.restart()
        } }
    }
    Process {
        id: applyProc
        onExited: function(code) {
            if (panel.cancelInFlight) { panel.applyInFlight = false; return }
            if (code === 0) { verifyProc.running = false; verifyProc.running = true }
            else { panel.applyInFlight = false; panel.restoreLast(); if (panel.queuedPath !== panel.lastSuccessfulPath) panel.applyTimer.restart() }
        }
    }
    Process {
        id: cancelProc
        onExited: function(code) {
            panel.cancelInFlight = false
            if (code === 0) {
                panel.lastSuccessfulPath = panel.sessionStartPath
                panel.currentPath = panel.sessionStartPath
            } else {
                console.warn("WallpaperSwitcher: cancel restore failed with code " + code)
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
        id: focusItem; anchors.fill: parent; focus: panel.visible
        Keys.priority: Keys.BeforeItem
        Keys.onPressed: function(e) { panel.handleKey(e) }
    }
    Item {
        id: body
        x: 24
        y: Math.round(Math.max(panel.topInset, Math.min(panel.height - panel.bottomInset - height, (panel.height - height) / 2)))
        width: panel.panelWidth; height: panel.panelHeight
        Repeater {
            model: panel.wallpapers
            delegate: Item {
                required property var modelData
                required property int index
                readonly property int distance: panel.signedDistance(index)
                readonly property int rank: Math.abs(distance)
                readonly property bool shown: distance === 0 || (rank <= panel.sideCapacity
                    && (panel.wallpapers.length === 2 || rank * 2 - (distance < 0 ? 1 : 0) <= panel.neighbourCount))
                readonly property real sideWidth: panel.sideCapacity > 0 ? panel.sideSpan / panel.sideCapacity : 0
                width: panel.previewWidth; height: panel.previewHeight + 38
                x: Math.round(body.width / 2 - width / 2 + (distance === 0 ? 0 : (distance < 0 ? -1 : 1) * (panel.previewWidth / 2 + 12 + sideWidth * (rank - 0.5))))
                y: Math.round((body.height - height) / 2)
                visible: shown; opacity: shown ? Math.max(0.28, 1 - rank * 0.18) : 0
                scale: distance === 0 ? 1 : Math.max(144 / panel.previewWidth, 0.78 - (rank - 1) * 0.12)
                z: 100 - rank
                Behavior on x { enabled: panel.root.wallpaperSwitcherVisible; NumberAnimation { duration: 210; easing.type: Easing.OutCubic } }
                Behavior on scale { enabled: panel.root.wallpaperSwitcherVisible; NumberAnimation { duration: 210; easing.type: Easing.OutCubic } }
                Behavior on opacity { enabled: panel.root.wallpaperSwitcherVisible; NumberAnimation { duration: 210 } }
                transform: Rotation {
                    origin.x: width / 2
                    origin.y: panel.previewHeight / 2
                    axis { x: 0; y: 1; z: 0 }
                    angle: distance === 0 ? 0 : (distance < 0 ? 13 : -13)
                    Behavior on angle {
                        enabled: panel.root.wallpaperSwitcherVisible
                        NumberAnimation { duration: 210 }
                    }
                }
                Rectangle {
                    width: parent.width; height: panel.previewHeight; radius: root.pillRadius; clip: true
                    color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, root.popupOverlayOpacity)
                    border.color: index === panel.selectedIndex ? root.seal : root.pillBorder
                    border.width: index === panel.selectedIndex ? 2 : root.pillBorderW
                    Image { anchors.fill: parent; source: parent.parent.shown ? "file://" + modelData.path : ""; fillMode: Image.PreserveAspectCrop; asynchronous: true; cache: true; smooth: true }
                }
                Text { anchors.top: parent.top; anchors.topMargin: panel.previewHeight + 10; width: parent.width; visible: index === panel.selectedIndex; text: modelData.label; elide: Text.ElideRight; horizontalAlignment: Text.AlignHCenter; color: root.ink; style: Text.Outline; styleColor: root.paper; font.family: root.mono; font.pixelSize: root.menuFontSize }
                MouseArea { anchors.fill: parent; onClicked: panel.selectedIndex = index; onDoubleClicked: { panel.selectedIndex = index; panel.confirmAndClose() } onWheel: function(e) { panel.move(e.angleDelta.y < 0 ? 1 : -1); e.accepted = true } }
            }
        }
    }
    onSelectedIndexChanged: requestApply()
    onVisibleChanged: {
        if (visible) {
            panel.beginSession()
            refresh()
        } else {
            applyTimer.stop()
            focusItem.focus = false
        }
    }
}
