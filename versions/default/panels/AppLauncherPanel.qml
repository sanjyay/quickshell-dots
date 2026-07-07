import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../modules"

PanelWindow {
    id: appPanel
    required property var root

    screen: root.activePopupScreen

    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "omarchy-app-launcher"
    WlrLayershell.keyboardFocus: root.appLauncherVisible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    readonly property int barBottom: 35
    readonly property int gap: 8
    readonly property int panelWidth: 430
    readonly property int rowHeight: 56
    readonly property int rowSpacing: 4
    readonly property int maxListHeight: 286
    readonly property int currentListHeight: filteredApps.length > 0
        ? Math.min(maxListHeight, filteredApps.length * rowHeight + Math.max(0, filteredApps.length - 1) * rowSpacing)
        : 80
    readonly property int panelHeight: 14 + 38 + 10 + currentListHeight + 14
    property string query: ""
    property int selectedIndex: 0
    property var apps: []
    property real reveal: root.appLauncherVisible ? 1 : 0
    readonly property color launcherAccent: root.seal
    readonly property color launcherAccentText: Qt.lighter(root.seal, 1.18)
    readonly property color launcherSelectedText: Qt.lighter(root.indigo, 1.35)
    readonly property color rowHighlight: Qt.rgba(1, 1, 1, 0.08)
    readonly property color rowHighlightStrong: Qt.rgba(1, 1, 1, 0.12)

    readonly property var filteredApps: {
        var q = query.trim().toLowerCase()
        var out = []
        for (var i = 0; i < apps.length; i++) {
            var app = apps[i]
            if (q === "" || app.name.toLowerCase().indexOf(q) >= 0) out.push(app)
        }
        return out
    }

    readonly property string scanCommand:
        "resolve_icon() { " +
        "case \"$1\" in " +
        "/*) [ -f \"$1\" ] && printf '%s' \"$1\"; return ;; " +
        "\"\") return ;; " +
        "esac; " +
        "for base in \"$HOME/.local/share/icons\" \"$HOME/.icons\" /usr/local/share/icons /usr/share/icons /usr/share/pixmaps; do " +
        "[ -d \"$base\" ] || continue; " +
        "found=$(find \"$base\" -type f \\( -iname \"$1.png\" -o -iname \"$1.svg\" -o -iname \"$1.xpm\" -o -iname \"$1.svgz\" \\) 2>/dev/null | sort -Vr | head -n1); " +
        "[ -n \"$found\" ] && printf '%s' \"$found\" && return; " +
        "done; " +
        "printf '%s' \"$1\"; " +
        "}; " +
        "for d in /usr/share/applications /usr/local/share/applications \"$HOME/.local/share/applications\"; do " +
        "[ -d \"$d\" ] || continue; find \"$d\" -maxdepth 1 -type f -name '*.desktop'; done | " +
        "while IFS= read -r f; do " +
        "grep -Eq '^(NoDisplay|Hidden)=true' \"$f\" && continue; " +
        "name=$(grep -m1 '^Name=' \"$f\" | cut -d= -f2-); " +
        "exec=$(grep -m1 '^Exec=' \"$f\" | cut -d= -f2-); " +
        "icon=$(grep -m1 '^Icon=' \"$f\" | cut -d= -f2-); " +
        "icon=$(resolve_icon \"$icon\"); " +
        "[ -n \"$name\" ] && [ -n \"$exec\" ] || continue; " +
        "printf '%s\\t%s\\t%s\\t%s\\n' \"$name\" \"$exec\" \"$icon\" \"$f\"; " +
        "done | sort -fu"

    Behavior on reveal {
        NumberAnimation {
            duration: root.appLauncherVisible ? 170 : 120
            easing.type: root.appLauncherVisible ? Easing.OutCubic : Easing.InCubic
        }
    }

    visible: reveal > 0.001
    onVisibleChanged: {
        if (visible) {
            query = ""
            resetListPosition()
            if (apps.length === 0) scanApps()
            focusTimer.restart()
            Qt.callLater(resetListPosition)
        }
    }
    onFilteredAppsChanged: selectedIndex = Math.max(0, Math.min(selectedIndex, filteredApps.length - 1))

    function scanApps() {
        scanProc.running = false
        scanProc.running = true
    }

    function iconSource(icon) {
        if (!icon) return ""
        return icon[0] === "/" ? "file://" + icon : icon
    }

    function hiddenApp(name, exec, file) {
        var key = ((name || "") + " " + (exec || "") + " " + (file || "")).toLowerCase()
        return key.indexOf("avahi") >= 0
            || key.indexOf("btop") >= 0
            || key.indexOf("fcitx") >= 0
    }

    function resetListPosition() {
        selectedIndex = 0
        appList.currentIndex = 0
        appList.contentY = 0
        appList.positionViewAtBeginning()
    }

    function setSelectedIndex(index) {
        if (filteredApps.length <= 0) {
            selectedIndex = 0
            return
        }

        selectedIndex = Math.max(0, Math.min(index, filteredApps.length - 1))
        appList.currentIndex = selectedIndex
        appList.positionViewAtIndex(selectedIndex, ListView.Contain)
    }

    function shellQuote(value) {
        return "'" + String(value).replace(/'/g, "'\\''") + "'"
    }

    function launch(app) {
        if (!app || !app.exec) return
        launchProc.command = ["bash", "-lc",
            "cmd=" + shellQuote(app.exec) + "; " +
            "cmd=$(printf '%s' \"$cmd\" | sed -E 's/ %[fFuUdDnNickvm]//g; s/%%/%/g'); " +
            "setsid sh -c \"$cmd\" >/dev/null 2>&1 &"
        ]
        launchProc.running = false
        launchProc.running = true
        root.appLauncherVisible = false
    }

    function launchSelected() {
        if (filteredApps.length > 0) launch(filteredApps[Math.max(0, Math.min(selectedIndex, filteredApps.length - 1))])
    }

    Process {
        id: scanProc
        command: ["bash", "-lc", appPanel.scanCommand]
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = this.text.trim().split("\n")
                var next = []
                var seen = {}
                for (var i = 0; i < lines.length; i++) {
                    var line = lines[i]
                    if (!line) continue
                    var parts = line.split("\t")
                    if (parts.length < 2) continue
                    var name = parts[0]
                    if (appPanel.hiddenApp(name, parts[1], parts[3] || "")) continue
                    if (seen[name]) continue
                    seen[name] = true
                    next.push({ name: name, exec: parts[1], icon: parts[2] || "", file: parts[3] || "" })
                }
                appPanel.apps = next
            }
        }
    }

    Process { id: launchProc }

    Timer {
        id: focusTimer
        interval: 40
        repeat: false
        onTriggered: searchField.forceActiveFocus()
    }

    MouseArea {
        anchors.fill: parent
        enabled: root.appLauncherVisible
        onClicked: root.appLauncherVisible = false
    }

    Rectangle {
        id: card
        width: appPanel.panelWidth
        height: appPanel.panelHeight
        radius: appPanel.reveal > 0.001 ? root.pillRadius : 0
        color: root.bg
        border.color: root.pillBorder
        border.width: root.pillBorderW
        PillShadow { theme: root }

        x: Math.round((parent.width - width) / 2)
        y: Math.round((parent.height - height) / 2)
        opacity: appPanel.reveal
        scale: 0.96 + appPanel.reveal * 0.04
        transformOrigin: Item.Top

        Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Escape) {
                root.appLauncherVisible = false
                event.accepted = true
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                appPanel.launchSelected()
                event.accepted = true
            } else if (event.key === Qt.Key_Down) {
                appPanel.setSelectedIndex(appPanel.selectedIndex + 1)
                event.accepted = true
            } else if (event.key === Qt.Key_Up) {
                appPanel.setSelectedIndex(appPanel.selectedIndex - 1)
                event.accepted = true
            }
        }

        MouseArea { anchors.fill: parent; onClicked: {} }

        Column {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 10

            Rectangle {
                width: parent.width
                height: 38
                radius: root.tileRadius
                color: root.fillIdle
                border.color: searchField.activeFocus ? appPanel.launcherAccent : root.sep
                border.width: 1
                Behavior on border.color { ColorAnimation { duration: 120 } }

                UiText {
                    anchors.left: parent.left
                    anchors.leftMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    text: ""
                    color: appPanel.launcherAccentText
                    font.family: root.mono
                    font.pixelSize: 13
                }

                TextInput {
                    id: searchField
                    anchors.left: parent.left
                    anchors.leftMargin: 34
                    anchors.right: parent.right
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    text: appPanel.query
                    color: root.ink
                    selectionColor: appPanel.rowHighlight
                    selectedTextColor: root.ink
                    font.family: root.mono
                    font.pixelSize: 13
                    clip: true
                    onTextChanged: {
                        appPanel.query = text
                        appPanel.selectedIndex = 0
                    }
                    Keys.onPressed: function(event) {
                        if (event.key === Qt.Key_Escape) {
                            root.appLauncherVisible = false
                            event.accepted = true
                        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            appPanel.launchSelected()
                            event.accepted = true
                        } else if (event.key === Qt.Key_Down) {
                            appPanel.setSelectedIndex(appPanel.selectedIndex + 1)
                            event.accepted = true
                        } else if (event.key === Qt.Key_Up) {
                            appPanel.setSelectedIndex(appPanel.selectedIndex - 1)
                            event.accepted = true
                        }
                    }
                }

                UiText {
                    anchors.left: searchField.left
                    anchors.verticalCenter: parent.verticalCenter
                    visible: searchField.text.length === 0 && !searchField.activeFocus
                    text: "Search apps"
                    color: root.sumi
                    font.family: root.mono
                    font.pixelSize: 13
                }
            }

            ListView {
                id: appList
                width: parent.width
                height: appPanel.currentListHeight
                clip: true
                spacing: appPanel.rowSpacing
                model: appPanel.filteredApps
                currentIndex: appPanel.selectedIndex
                onContentYChanged: {
                    if (moving || dragging || flicking) {
                        var idx = indexAt(width / 2, contentY + 4)
                        if (idx >= 0) appPanel.selectedIndex = idx
                    }
                }

                delegate: Item {
                    id: row
                    required property var modelData
                    property bool hovered: false
                    readonly property bool active: ListView.isCurrentItem || hovered
                    width: appList.width
                    height: appPanel.rowHeight

                    Rectangle {
                        anchors.fill: parent
                        anchors.leftMargin: 2
                        anchors.rightMargin: 2
                        radius: 12
                        color: row.active ? appPanel.rowHighlight : "transparent"
                        border.color: row.active ? appPanel.rowHighlightStrong : "transparent"
                        border.width: 1
                        Behavior on color { ColorAnimation { duration: 100 } }
                        Behavior on border.color { ColorAnimation { duration: 100 } }
                    }

                    UiText {
                        anchors.left: parent.left
                        anchors.leftMargin: 22
                        anchors.right: parent.right
                        anchors.rightMargin: 22
                        anchors.verticalCenter: parent.verticalCenter
                        text: row.modelData.name
                        color: row.active ? appPanel.launcherSelectedText : appPanel.launcherAccentText
                        elide: Text.ElideRight
                        font.family: root.mono
                        font.pixelSize: 13
                        Behavior on color { ColorAnimation { duration: 100 } }
                    }

                    MouseArea {
                        id: rowMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: {
                            row.hovered = true
                            appPanel.setSelectedIndex(index)
                        }
                        onExited: row.hovered = false
                        onClicked: appPanel.launch(row.modelData)
                    }
                }

                UiText {
                    anchors.centerIn: parent
                    visible: appPanel.filteredApps.length === 0
                    text: appPanel.apps.length === 0 ? "Scanning applications..." : "No matches"
                    color: root.sumi
                    font.family: root.mono
                    font.pixelSize: 12
                }
            }
        }
    }
}
