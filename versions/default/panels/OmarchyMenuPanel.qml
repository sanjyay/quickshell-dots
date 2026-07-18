import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../modules"
import "../models/OmarchyMenuModel.js" as MenuModel

PanelWindow {
    id: menuPanel
    required property var root

    screen: root.activePopupScreen
    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-menu"
    WlrLayershell.keyboardFocus: root.menuVisible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    property string activeMenu: "root"
    property var menuStack: []
    property string typeAheadQuery: ""
    property int selectedIndex: 0
    property string statusText: ""
    property string pendingAction: ""
    property var dynamicRows: ({})
    property string pendingDynamicSource: ""
    property bool dynamicResultReceived: false
    readonly property bool inputDebug: Quickshell.env("QS_MENU_INPUT_DEBUG") === "1"
    readonly property bool nestedMenu: activeMenu !== "root"
    readonly property bool unlockMenu: activeMenu === "style.unlocks"
    readonly property int unlockPreviewHeight: unlockMenu ? 184 : 0
    readonly property int menuRowHeight: nestedMenu ? 36 : root.menuRowHeight
    readonly property int menuRowSpacing: nestedMenu ? 2 : root.menuRowSpacing
    readonly property int menuListNaturalHeight: Math.max(menuRowHeight,
        rows().length * menuRowHeight + Math.max(0, rows().length - 1) * menuRowSpacing)
    // The nested header, separator, breadcrumb, Column spacing, and card margins.
    // Keep this explicit so the card never clips the last row when it grows.
    readonly property int nestedMenuChromeHeight: menuStack.length > 0 ? 88 : 69
    readonly property int menuTopInset: root.barPosition === "top" ? 43 : 8
    readonly property int menuBottomInset: root.barPosition === "bottom" ? 43 : 8
    readonly property int menuAvailableHeight: Math.max(1, height - menuTopInset - menuBottomInset)
    readonly property int menuListHeight: Math.min(menuListNaturalHeight,
        Math.max(menuRowHeight, menuAvailableHeight - (nestedMenu ? nestedMenuChromeHeight : 28) - unlockPreviewHeight))
    property real reveal: root.menuVisible ? 1 : 0

    visible: reveal > 0.001

    function inputDebugLog(message) {
        if (inputDebug) console.log("OmarchyMenu input: " + message)
    }

    function openMenu(route) {
        activeMenu = route || "root"
        menuStack = []
        resetTypeAhead()
        setSelection(0)
        statusText = ""
        loadDynamicMenu(MenuModel.dynamicSource(activeMenu))
        root.activateFocusedPopupScreen()
        root.menuVisible = true
        focusTimer.restart()
    }

    function closeMenu() {
        root.menuVisible = false
        pendingAction = ""
        resetTypeAhead()
    }

    function rows() {
        var source = MenuModel.dynamicSource(activeMenu)
        if (source) {
            if (dynamicRows[source] !== undefined) return dynamicRows[source]
            return [{ icon: "•", label: "Loading…", detail: "Retrieving current system options", enabledRow: false }]
        }
        return MenuModel.children(activeMenu)
    }

    function setDynamicRows(source, values) {
        var next = {}
        for (var key in dynamicRows) next[key] = dynamicRows[key]
        next[source] = values
        dynamicRows = next
        if (MenuModel.dynamicSource(activeMenu) === source) setSelection(0)
    }

    function loadDynamicMenu(source) {
        if (!source || dataProc.running || dynamicRows[source] !== undefined) return
        pendingDynamicSource = source
        dynamicResultReceived = false
        dataProc.command = [Quickshell.env("HOME") + "/.local/bin/qs-menu-data", source]
        dataProc.running = false
        dataProc.running = true
    }

    function cardY(cardHeight) {
        var centered = (height - cardHeight) / 2
        return Math.round(Math.max(menuTopInset,
            Math.min(height - menuBottomInset - cardHeight, centered)))
    }

    function setSelection(index) {
        var count = rows().length
        selectedIndex = count > 0 ? Math.max(0, Math.min(index, count - 1)) : 0
        if (actionList) actionList.select(selectedIndex)
    }

    function resetTypeAhead() {
        typeAheadQuery = ""
        typeAheadTimer.stop()
    }

    function normalizedLabel(entry) {
        return String(entry && entry.label || "").trim().toLowerCase()
    }

    function selectTypeAhead(text, replaceQuery) {
        var all = rows()
        if (all.length === 0) return

        var lower = text.toLowerCase()
        var repeated = !replaceQuery && typeAheadQuery.length > 0 &&
            typeAheadQuery.split("").every(function(character) { return character === lower }) &&
            lower === typeAheadQuery[0]
        var candidateQuery = replaceQuery ? text.toLowerCase() : (repeated ? lower : (typeAheadQuery + lower))
        var prefix = []
        var contains = []
        for (var i = 0; i < all.length; i++) {
            var label = normalizedLabel(all[i])
            if (label.indexOf(candidateQuery) === 0) prefix.push(i)
            else if (label.indexOf(candidateQuery) >= 0) contains.push(i)
        }

        // If a longer buffer has no result, start a fresh query with this key.
        if (prefix.length === 0 && contains.length === 0 && candidateQuery !== lower) {
            candidateQuery = lower
            prefix = []
            contains = []
            for (var j = 0; j < all.length; j++) {
                var freshLabel = normalizedLabel(all[j])
                if (freshLabel.indexOf(candidateQuery) === 0) prefix.push(j)
                else if (freshLabel.indexOf(candidateQuery) >= 0) contains.push(j)
            }
        }

        var matches = prefix.length > 0 ? prefix : contains
        if (matches.length > 0) {
            var next = matches[0]
            if (repeated) {
                for (var k = 0; k < matches.length; k++) {
                    if (matches[k] > selectedIndex) { next = matches[k]; break }
                }
            }
            setSelection(next)
        }

        typeAheadQuery = candidateQuery
        typeAheadTimer.restart()
    }

    function selectedRow() {
        var current = rows()
        return current.length > 0 ? current[Math.min(selectedIndex, current.length - 1)] : null
    }

    function localFileUrl(path) {
        return path ? encodeURI("file://" + path) : ""
    }

    function handleKey(event) {
        var count = rows().length
        var before = selectedIndex
        var branch = "unhandled"
        if (event.key === Qt.Key_Escape) {
            branch = menuStack.length > 0 ? "parentMenu" : "close"
            if (menuStack.length > 0) goBack()
            else closeMenu()
            event.accepted = true
        } else if (event.key === Qt.Key_Backspace) {
            branch = "backspace"
            if (typeAheadQuery.length > 0) {
                typeAheadQuery = typeAheadQuery.slice(0, -1)
                if (typeAheadQuery.length > 0) selectTypeAhead(typeAheadQuery, true)
                else typeAheadTimer.stop()
            } else if (menuStack.length > 0) {
                goBack()
            }
            event.accepted = true
        } else if (event.key === Qt.Key_Down) {
            branch = "moveNext"
            resetTypeAhead()
            if (count > 0) setSelection((selectedIndex + 1) % count)
            event.accepted = true
        } else if (event.key === Qt.Key_Up) {
            branch = "movePrevious"
            resetTypeAhead()
            if (count > 0) setSelection((selectedIndex - 1 + count) % count)
            event.accepted = true
        } else if (event.key === Qt.Key_PageDown) {
            branch = "pageDown"
            resetTypeAhead()
            if (count > 0) setSelection(Math.min(count - 1, selectedIndex + 5))
            event.accepted = true
        } else if (event.key === Qt.Key_PageUp) {
            branch = "pageUp"
            resetTypeAhead()
            if (count > 0) setSelection(Math.max(0, selectedIndex - 5))
            event.accepted = true
        } else if (event.key === Qt.Key_Home) {
            branch = "home"
            resetTypeAhead()
            if (count > 0) setSelection(0)
            event.accepted = true
        } else if (event.key === Qt.Key_End) {
            branch = "end"
            resetTypeAhead()
            if (count > 0) setSelection(count - 1)
            event.accepted = true
        } else if (event.key === Qt.Key_Left) {
            branch = "parentMenu"
            resetTypeAhead()
            if (menuStack.length > 0) goBack()
            event.accepted = true
        } else if (event.key === Qt.Key_Right) {
            branch = "childMenu"
            resetTypeAhead()
            var rightRow = selectedRow()
            if (rightRow && rightRow.type === "submenu") activateRow(rightRow)
            event.accepted = true
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            branch = "activate"
            activateRow(selectedRow())
            event.accepted = true
        } else if (event.text && event.text.length === 1 && event.text.charCodeAt(0) >= 32) {
            branch = "typeAhead"
            selectTypeAhead(event.text)
            event.accepted = true
        }
        inputDebugLog("key=" + event.key + " text=" + event.text +
            " modifiers=" + event.modifiers + " autoRepeat=" + event.isAutoRepeat +
            " before=" + before + " count=" + count + " branch=" + branch +
            " after=" + selectedIndex + " accepted=" + event.accepted)
    }

    function activateRow(entry) {
        if (!entry) return
        if (entry.type === "submenu") {
            if (!entry.submenuId || typeof entry.submenuId !== "string") return
            menuStack = menuStack.concat([activeMenu])
            activeMenu = entry.submenuId
            resetTypeAhead()
            setSelection(0)
            loadDynamicMenu(MenuModel.dynamicSource(activeMenu))
            focusTimer.restart()
            return
        }

        var action = String(entry.actionId || "").trim()
        if (!action) return
        if (action === "open-theme-switcher") {
            root.openThemeSwitcher()
            return
        }
        if (action === "open-wallpaper-switcher") {
            root.openWallpaperSwitcher()
            return
        }
        root.menuVisible = false
        var value = String(entry.dynamicValue || "")
        actionProc.command = value ? ["qs-menu-action", action, value] : ["qs-menu-action", action]
        actionProc.running = false
        actionProc.running = true
    }

    function goBack() {
        resetTypeAhead()
        if (menuStack.length > 0) {
            var next = menuStack.slice(0, menuStack.length - 1)
            activeMenu = menuStack[menuStack.length - 1]
            menuStack = next
            setSelection(0)
            return
        }
        closeMenu()
    }

    Timer {
        id: typeAheadTimer
        interval: 900
        repeat: false
        onTriggered: menuPanel.typeAheadQuery = ""
    }

    Timer {
        id: focusTimer
        interval: 40
        repeat: false
        onTriggered: if (root.menuVisible && menuPanel.visible) keyboardInput.forceActiveFocus()
    }

    MouseArea {
        anchors.fill: parent
        z: 0
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onClicked: menuPanel.closeMenu()
    }

    Rectangle {
        anchors.centerIn: parent
        width: Math.min(330, parent.width - 32)
        height: 150
        visible: menuPanel.pendingAction.length > 0 && root.menuVisible
        radius: root.pillRadius
        color: root.bg
        border.color: root.seal
        z: 20
        Column {
            anchors.fill: parent; anchors.margins: 16; spacing: 12
            Text { text: "Confirm system action?"; color: root.ink; font.family: root.mono; font.pixelSize: 13 }
            Text { text: "Press Enter to continue or Escape to cancel."; color: root.sumi; font.family: root.mono; font.pixelSize: 10 }
            Row { spacing: 8
                Button { text: "Cancel"; onClicked: menuPanel.pendingAction = "" }
                Button { text: "Continue"; onClicked: menuPanel.confirmPending() }
            }
        }
        Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Escape) { menuPanel.pendingAction = ""; event.accepted = true }
            else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) { menuPanel.confirmPending(); event.accepted = true }
        }
    }

    Rectangle {
        id: card
        width: Math.min(menuPanel.unlockMenu ? 640 : 360, parent.width - 24)
        height: Math.min(menuPanel.menuAvailableHeight,
            menuPanel.menuListHeight + (menuPanel.nestedMenu ? menuPanel.nestedMenuChromeHeight : 28)
                + menuPanel.unlockPreviewHeight)
        x: Math.round((parent.width - width) / 2)
        y: menuPanel.cardY(height)
        radius: root.pillRadius
        color: root.bg
        border.color: root.pillBorder
        border.width: root.pillBorderW
        clip: true
        PillShadow { theme: root }

        // Match the launcher: a real focused TextInput is the compositor-facing
        // keyboard owner. It is intentionally invisible and never displays the
        // type-ahead buffer.
        TextInput {
            id: keyboardInput
            width: 1
            height: 1
            opacity: 0
            color: "transparent"
            selectionColor: "transparent"
            selectedTextColor: "transparent"
            cursorVisible: false
            clip: true
            text: ""
            onActiveFocusChanged: menuPanel.inputDebugLog("keyboardInput.activeFocus=" + activeFocus)
            onTextChanged: {
                if (text.length > 0) {
                    var typed = text
                    text = ""
                    menuPanel.inputDebugLog("text=" + typed)
                    menuPanel.selectTypeAhead(typed)
                }
            }
            Keys.priority: Keys.BeforeItem
            Keys.onPressed: function(event) {
                menuPanel.inputDebugLog("key=" + event.key + " text=" + event.text + " activeFocus=" + activeFocus)
                menuPanel.handleKey(event)
            }
        }

        MouseArea { anchors.fill: parent; onClicked: {} }

        Column {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 8

            Row {
                width: parent.width
                height: 24
                visible: menuPanel.activeMenu !== "root"
                spacing: 8

                Text {
                    width: parent.width - 36
                    anchors.verticalCenter: parent.verticalCenter
                    text: menuPanel.activeMenu === "root" ? "" : (MenuModel.find(menuPanel.activeMenu) || {label: "Menu"}).label
                    color: root.ink
                    font.family: root.mono
                    font.pixelSize: 15
                    font.weight: Font.Bold
                    font.letterSpacing: 2
                }

            }

            Rectangle { width: parent.width; height: 1; color: root.sep; visible: menuPanel.activeMenu !== "root" }

            Rectangle {
                width: parent.width
                height: menuPanel.unlockPreviewHeight
                visible: menuPanel.unlockMenu
                radius: root.menuRowRadius
                color: root.frameWeak
                border.color: root.pillBorder
                border.width: root.pillBorderW
                clip: true

                Image {
                    id: unlockPreview
                    anchors.fill: parent
                    anchors.margins: 4
                    source: {
                        var row = menuPanel.selectedRow()
                        return menuPanel.localFileUrl(row && row.previewPath || "")
                    }
                    asynchronous: true
                    cache: false
                    fillMode: Image.PreserveAspectFit
                    sourceSize.width: 624
                    sourceSize.height: 176
                }

                Text {
                    anchors.centerIn: parent
                    visible: unlockPreview.source === "" || unlockPreview.status === Image.Error
                    text: unlockPreview.status === Image.Error ? "Preview unavailable" : "Default Omarchy unlock screen"
                    color: root.sumi
                    font.family: root.mono
                    font.pixelSize: 11
                }
            }

            Text {
                width: parent.width
                visible: menuPanel.menuStack.length > 0
                text: "Go  ›  " + menuPanel.menuStack.map(function(id) { return (MenuModel.find(id) || {label: id}).label }).join("  ›  ")
                color: root.sumiHi
                font.family: root.mono
                font.pixelSize: 9
                elide: Text.ElideRight
            }

            SelectableList {
                id: actionList
                width: parent.width
                height: menuPanel.menuListHeight
                model: menuPanel.rows()
                selectedIndex: 0
                rowHeight: menuPanel.menuRowHeight
                rowSpacing: menuPanel.menuRowSpacing
                fontSize: root.menuFontSize
                fontWeight: root.menuFontWeight
                fontFamily: root.mono
                rowRadius: root.menuRowRadius
                textColor: root.ink
                mutedColor: root.seal
                accentColor: root.seal
                selectedColor: root.fillHover
                borderColor: root.seal
                showScrollBar: menuPanel.menuListNaturalHeight > menuPanel.menuListHeight
                onHovered: function(index) { menuPanel.setSelection(index) }
                onActivated: function(index) {
                    menuPanel.activateRow(menuPanel.rows()[index])
                    menuPanel.focusTimer.restart()
                }
            }

            Text {
                width: parent.width
                visible: menuPanel.statusText.length > 0
                text: menuPanel.statusText
                color: root.seal
                font.family: root.mono
                font.pixelSize: 9
                elide: Text.ElideRight
            }
        }
    }

    onVisibleChanged: if (visible) {
        inputDebugLog("visible=true keyboardFocus=Exclusive")
        openMenu(root.menuRoute)
        focusTimer.restart()
    }

    Connections {
        target: root
        function onMenuVisibleChanged() {
            if (root.menuVisible) menuPanel.openMenu(root.menuRoute)
        }
        function onMenuRouteChanged() {
            if (root.menuVisible) menuPanel.openMenu(root.menuRoute)
        }
    }

    Process {
        id: dataProc
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                var source = menuPanel.pendingDynamicSource
                var values = []
                var lines = this.text.split("\n")
                for (var i = 0; i < lines.length; i++) {
                    var parts = lines[i].split("\t")
                    if (parts.length < 4 || !parts[1] || !parts[3]) continue
                    values.push({ icon: parts[0] || "•", label: parts[1], detail: parts[2] || "",
                                  type: "action", actionId: parts[3], dynamicValue: parts[4] || "",
                                  previewPath: parts[5] || "" })
                }
                if (values.length === 0)
                    values = [{ icon: "•", label: "No entries available", detail: "The system returned no selectable items", enabledRow: false }]
                menuPanel.dynamicResultReceived = true
                menuPanel.setDynamicRows(source, values)
            }
        }
        onExited: function(code) {
            if (code !== 0 && !menuPanel.dynamicResultReceived) {
                menuPanel.setDynamicRows(menuPanel.pendingDynamicSource,
                    [{ icon: "•", label: "Unable to retrieve options", detail: "Try opening this menu again", enabledRow: false }])
            }
        }
    }

    Process {
        id: actionProc
        running: false
        onExited: function(code) {
            if (code !== 0) menuPanel.statusText = "Action failed (" + code + ")"
        }
    }

    function confirmPending() {
        if (!pendingAction) return
        var action = pendingAction
        pendingAction = ""
        root.menuVisible = false
        actionProc.command = ["qs-menu-action", action]
        actionProc.running = false; actionProc.running = true
    }

    onSelectedIndexChanged: inputDebugLog("selection changed to " + selectedIndex)
}
