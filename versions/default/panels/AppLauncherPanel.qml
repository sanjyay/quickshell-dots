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
    readonly property int rowHeight: root.menuRowHeight
    readonly property int rowSpacing: root.menuRowSpacing
    readonly property int maxVisibleRows: 6
    readonly property int maxListHeight: maxVisibleRows * rowHeight + (maxVisibleRows - 1) * rowSpacing
    readonly property int currentListHeight: filteredApps.length > 0
        ? Math.min(maxListHeight, filteredApps.length * rowHeight + Math.max(0, filteredApps.length - 1) * rowSpacing)
        : 80
    readonly property int panelHeight: 14 + 38 + 10 + currentListHeight + 14
    property string query: ""
    property int selectedIndex: 0
    property var apps: []
    property bool cacheLoaded: false
    property bool scanningApps: false
    property real reveal: root.appLauncherVisible ? 1 : 0
    readonly property string cachePath: Quickshell.env("HOME") + "/.cache/quickshell/app-launcher/apps.json"
    readonly property color launcherAccent: root.seal
    readonly property color launcherAccentText: root.seal
    readonly property color launcherSelectedText: root.ink
    readonly property color rowHighlight: root.fillHover
    readonly property color rowHighlightStrong: root.seal
    readonly property color launcherSurface: Qt.rgba(root.paper.r, root.paper.g, root.paper.b, 1)

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
        "python3 -c " + shellQuote(
            "import configparser, json, os, sys, tempfile\n" +
            "cache = os.path.expanduser('~/.cache/quickshell/app-launcher/apps.json')\n" +
            "print('APP_LAUNCHER rescan started cache=' + cache, file=sys.stderr)\n" +
            "dirs = [os.path.expanduser('~/.local/share/applications'), os.path.expanduser('~/.local/share/flatpak/exports/share/applications'), '/var/lib/flatpak/exports/share/applications', '/usr/local/share/applications', '/usr/share/applications']\n" +
            "icon_bases = [os.path.expanduser('~/.local/share/icons'), os.path.expanduser('~/.icons'), os.path.expanduser('~/.local/share/flatpak/exports/share/icons'), '/var/lib/flatpak/exports/share/icons', '/usr/local/share/icons', '/usr/share/icons', '/usr/share/pixmaps']\n" +
            "def resolve_icon(icon):\n" +
            "    if not icon: return ''\n" +
            "    if icon.startswith('/'): return icon if os.path.isfile(icon) else icon\n" +
            "    names = [icon] if os.path.splitext(icon)[1] else [icon + ext for ext in ('.png', '.svg', '.xpm', '.svgz')]\n" +
            "    for base in icon_bases:\n" +
            "        if not os.path.isdir(base): continue\n" +
            "        for root, _, files in os.walk(base):\n" +
            "            fs = set(files)\n" +
            "            for name in names:\n" +
            "                if name in fs: return os.path.join(root, name)\n" +
            "    return icon\n" +
            "def field(cp, key):\n" +
            "    return cp.get('Desktop Entry', key, fallback='').strip()\n" +
            "apps, seen = [], set()\n" +
            "for d in dirs:\n" +
            "    if not os.path.isdir(d): continue\n" +
            "    for fn in sorted(os.listdir(d)):\n" +
            "        if not fn.endswith('.desktop'): continue\n" +
            "        path = os.path.join(d, fn)\n" +
            "        cp = configparser.ConfigParser(interpolation=None, strict=False)\n" +
            "        cp.optionxform = str\n" +
            "        try: cp.read(path, encoding='utf-8')\n" +
            "        except Exception: continue\n" +
            "        if not cp.has_section('Desktop Entry'): continue\n" +
            "        if field(cp, 'NoDisplay').lower() == 'true' or field(cp, 'Hidden').lower() == 'true': continue\n" +
            "        name, exec_cmd = field(cp, 'Name'), field(cp, 'Exec')\n" +
            "        if not name or not exec_cmd: continue\n" +
            "        key = (name + ' ' + exec_cmd + ' ' + path).lower()\n" +
            "        if any(x in key for x in ('avahi', 'btop', 'fcitx')): continue\n" +
            "        if name in seen: continue\n" +
            "        seen.add(name)\n" +
            "        apps.append({'name': name, 'exec': exec_cmd, 'icon': resolve_icon(field(cp, 'Icon')), 'file': path, 'categories': field(cp, 'Categories'), 'keywords': field(cp, 'Keywords'), 'mtime': int(os.path.getmtime(path)) if os.path.exists(path) else 0})\n" +
            "apps.sort(key=lambda a: a['name'].lower())\n" +
            "payload = {'version': 1, 'generatedAt': int(__import__('time').time()), 'apps': apps}\n" +
            "try:\n" +
            "    os.makedirs(os.path.dirname(cache), exist_ok=True)\n" +
            "    fd, tmp = tempfile.mkstemp(prefix='apps.', suffix='.json.tmp', dir=os.path.dirname(cache), text=True)\n" +
            "    with os.fdopen(fd, 'w', encoding='utf-8') as f: json.dump(payload, f, ensure_ascii=False, separators=(',', ':'))\n" +
            "    os.replace(tmp, cache)\n" +
            "    print('APP_LAUNCHER cache write success count=%d path=%s' % (len(apps), cache), file=sys.stderr)\n" +
            "except Exception as e:\n" +
            "    print('APP_LAUNCHER cache write failure path=%s error=%s' % (cache, e), file=sys.stderr)\n" +
            "print(json.dumps(payload, ensure_ascii=False))\n" +
            "print('APP_LAUNCHER rescan finished count=%d' % len(apps), file=sys.stderr)\n"
        )

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
            if (!cacheLoaded) loadCachedApps()
            if (!scanningApps) scanApps()
            focusTimer.restart()
            Qt.callLater(resetListPosition)
        }
    }
    onFilteredAppsChanged: setSelectedIndex(selectedIndex)
    Component.onCompleted: {
        console.log("AppLauncher cache path " + cachePath)
        loadCachedApps()
    }

    function scanApps() {
        scanningApps = true
        console.log("AppLauncher rescan started")
        scanProc.running = false
        scanProc.running = true
    }

    function loadCachedApps() {
        console.log("AppLauncher cache load started path=" + cachePath)
        cacheProc.running = false
        cacheProc.running = true
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

    function parseCachedApps(text) {
        var payload = JSON.parse(String(text || "{}"))
        var list = payload.apps || []
        var next = []
        var seen = {}
        for (var i = 0; i < list.length; i++) {
            var app = list[i]
            if (!app || !app.name || !app.exec) continue
            if (hiddenApp(app.name, app.exec, app.file || "")) continue
            if (seen[app.name]) continue
            seen[app.name] = true
            next.push({
                name: app.name,
                exec: app.exec,
                icon: app.icon || "",
                file: app.file || "",
                categories: app.categories || "",
                keywords: app.keywords || "",
                mtime: app.mtime || 0
            })
        }
        return next
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
        id: cacheProc
        command: ["bash", "-lc",
            "p=" + appPanel.shellQuote(appPanel.cachePath) + "; " +
            "printf 'APP_LAUNCHER cache path %s\\n' \"$p\" >&2; " +
            "if [ -s \"$p\" ]; then cat \"$p\"; else printf 'APP_LAUNCHER cache load failure path=%s reason=missing-or-empty\\n' \"$p\" >&2; fi"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    if (String(this.text || "").trim() === "") throw "missing-or-empty"
                    var next = appPanel.parseCachedApps(this.text)
                    if (next.length > 0) appPanel.apps = next
                    appPanel.cacheLoaded = true
                    console.log("AppLauncher cache load success count=" + next.length + " path=" + appPanel.cachePath)
                } catch (e) {
                    appPanel.cacheLoaded = true
                    console.warn("AppLauncher cache load failure path=" + appPanel.cachePath + " error=" + e)
                }
                if (!appPanel.scanningApps) appPanel.scanApps()
            }
        }
    }

    Process {
        id: scanProc
        command: ["bash", "-lc", appPanel.scanCommand]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var next = appPanel.parseCachedApps(this.text)
                    appPanel.apps = next
                    console.log("AppLauncher rescan finished count=" + next.length)
                    console.log("AppLauncher cache write success path=" + appPanel.cachePath)
                } catch (e) {
                    console.warn("AppLauncher rescan parse failure error=" + e)
                }
                appPanel.scanningApps = false
            }
        }
        onExited: function(exitCode) {
            appPanel.scanningApps = false
            console.log("AppLauncher rescan process exited code=" + exitCode)
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
        color: appPanel.launcherSurface
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
            spacing: root.menuRowSpacing + 7

            Rectangle {
                width: parent.width
                height: 38
                radius: root.menuRowRadius
                color: appPanel.launcherSurface
                border.color: appPanel.launcherAccent
                border.width: root.pillBorderW
                Behavior on border.color { ColorAnimation { duration: 120 } }

                UiText {
                    anchors.left: parent.left
                    anchors.leftMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    text: ""
                    color: appPanel.launcherAccentText
                    font.family: root.mono
                    font.pixelSize: root.menuFontSize
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
                    font.pixelSize: root.menuFontSize
                    font.weight: root.menuFontWeight
                    clip: true
                    onTextChanged: {
                        appPanel.query = text
                        appPanel.setSelectedIndex(0)
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
                    font.pixelSize: root.menuFontSize
                    font.weight: root.menuFontWeight
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
                    required property int index
                    required property var modelData
                    readonly property bool active: appPanel.selectedIndex === row.index
                    width: appList.width
                    height: appPanel.rowHeight

                    Rectangle {
                        anchors.fill: parent
                        radius: root.menuRowRadius
                        color: row.active ? appPanel.rowHighlight : "transparent"
                        border.color: row.active ? appPanel.rowHighlightStrong : "transparent"
                        border.width: row.active ? root.pillBorderW : 0
                        Behavior on color { ColorAnimation { duration: 100 } }
                        Behavior on border.color { ColorAnimation { duration: 100 } }
                    }

                    UiText {
                        anchors.left: parent.left
                        anchors.leftMargin: 42
                        anchors.right: parent.right
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        text: row.modelData.name
                        color: row.active ? appPanel.launcherSelectedText : appPanel.launcherAccentText
                        elide: Text.ElideRight
                        font.family: root.mono
                        font.pixelSize: root.menuFontSize
                        font.weight: root.menuFontWeight
                        Behavior on color { ColorAnimation { duration: 100 } }
                    }

                    MouseArea {
                        id: rowMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: appPanel.setSelectedIndex(row.index)
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
