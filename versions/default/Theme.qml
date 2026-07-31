import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Services.UPower
import qs.Commons
import "modules"
import "services"

Item {
    id: theme

    // Keep automatic widget visibility independent of which monitor's bar
    // happens to instantiate the MPRIS widget. This also avoids a bar being
    // destroyed briefly clearing the shared playback state.
    MprisSelect { id: mediaSelection }

    property var cameraSwitch: null
    property var calendarHolidayConfig: ({})

    Component.onCompleted: {
        console.log("Theme.qml completed cameraSwitch=" + (cameraSwitch ? cameraSwitch.monitorVersion : "null"))
        refreshTailscale()
        mediaTrackArmTimer.restart()
    }
    onCameraSwitchChanged: console.log("Theme.qml cameraSwitch changed cameraSwitch=" + (cameraSwitch ? cameraSwitch.monitorVersion : "null"))

    readonly property color paper: Color.bar.background
    readonly property color ink: Color.bar.text
    readonly property color inkDeep: Color.foreground
    readonly property color sumi: Color.bar.text
    readonly property color sumiHi:  Qt.rgba(sumi.r*0.45 + ink.r*0.55, sumi.g*0.45 + ink.g*0.55, sumi.b*0.45 + ink.b*0.55, 1.0)  // lifted section-header text
    readonly property color indigo: Color.accent
    property color green:   "#8a9a73"   // gate "OK" verdict
    property color color02: "#8a9a73"   // colors.toml color2
    property color color03: "#c8b36a"   // colors.toml color3
    readonly property color sealRaw: Color.urgent
    readonly property color accentHint: Color.accent
    readonly property int barReservedExtent: 38
    property string barColor: "red"
    readonly property bool pointerTrace: Quickshell.env("QS_POINTER_TRACE") === "1"
    property real pointerTraceX: -1
    property real pointerTraceY: -1
    property string pointerTraceLabel: ""

    function tracePointer(item, label, event, action) {
        if (!pointerTrace || !item) return
        var p = item.mapToItem(null, 0, 0)
        var chain = []
        var current = item
        while (current && chain.length < 12) {
            chain.push((current.objectName || current.toString())
                + "@" + current.x + "," + current.y + ":" + current.width + "x" + current.height
                + ":v=" + current.visible + ":e=" + current.enabled + ":o=" + current.opacity
                + ":z=" + current.z + ":clip=" + current.clip)
            current = current.parent
        }
        pointerTraceX = p.x + (event && event.x !== undefined ? event.x : item.width / 2)
        pointerTraceY = p.y + (event && event.y !== undefined ? event.y : item.height / 2)
        pointerTraceLabel = label + (action ? " -> " + action : "")
        console.log("POINTER_TRACE label=" + label
            + " action=" + (action || "")
            + " scene=" + pointerTraceX + "," + pointerTraceY
            + " local=" + (event && event.x !== undefined ? event.x + "," + event.y : "n/a")
            + " item=" + p.x + "," + p.y + " " + item.width + "x" + item.height
            + " visible=" + item.visible + " enabled=" + item.enabled
            + " opacity=" + item.opacity + " z=" + item.z + " clip=" + item.clip
            + " accepted=" + (event && event.accepted !== undefined ? event.accepted : "n/a")
            + " parentChain=" + chain.join(" <- "))
    }

    function traceGeometry(item, label) {
        if (!pointerTrace || !item) return
        var p = item.mapToItem(null, 0, 0)
        console.log("POINTER_GEOMETRY label=" + label
            + " scene=" + p.x + "," + p.y + " " + item.width + "x" + item.height
            + " visible=" + item.visible + " enabled=" + item.enabled
            + " opacity=" + item.opacity + " z=" + item.z + " clip=" + item.clip)
    }

    readonly property color baseSeal: barColorValue(barColor)
    readonly property color seal: baseSeal
    readonly property var barColorOptions: [
        { id: "red",    label: "Red",    color: sealRaw },
        { id: "mauve",  label: "Mauve",  color: "#cba6f7" },
        { id: "purple", label: "Purple", color: "#9d7cd8" },
        { id: "blue",   label: "Blue",   color: "#7aa2f7" }
    ]
    function barColorValue(id) {
        for (var i = 0; i < barColorOptions.length; i++)
            if (barColorOptions[i].id === id) return barColorOptions[i].color
        return sealRaw
    }
    function barColorValid(id) {
        for (var i = 0; i < barColorOptions.length; i++)
            if (barColorOptions[i].id === id) return true
        return false
    }
    function barColorLabel(id) {
        for (var i = 0; i < barColorOptions.length; i++)
            if (barColorOptions[i].id === id) return barColorOptions[i].label
        return "Red"
    }
    property string mono: "JetBrainsMono Nerd Font"
    readonly property int menuRowHeight: 42
    readonly property int menuRowSpacing: 3
    readonly property int menuFontSize: 18
    readonly property int menuFontWeight: Font.DemiBold
    readonly property int menuRowRadius: 6

    // ── transparency knobs (0.0 = fully transparent, 1.0 = opaque) ──
    property real barOpacity:  0.94   // große Insel / Split-Sektionen
    property real pillOpacity: 0.18   // einzelne Widget-Pillen (workspace, mem, cpu, …)

    readonly property color bg:     Qt.rgba(paper.r, paper.g, paper.b, barOpacity)
    // bar island/section bg ONLY (NOT the shared bg -> panels keep their opacity): Frost
    // lowers the island alpha; compositor blur appears automatically when the theme
    // already blurs Quickshell layer surfaces.
    readonly property color barBg:  Qt.rgba(paper.r, paper.g, paper.b,
                                            styleFrost ? Math.min(barOpacity, 0.68) : barOpacity)
    readonly property color pill:   Qt.rgba(paper.r, paper.g, paper.b, pillOpacity)
    readonly property color fg:     ink
    readonly property color muted:  sumi
    readonly property color accent: seal
    readonly property color warn:   seal
    readonly property color sep:    Qt.rgba(ink.r, ink.g, ink.b, 0.18)

    // ── interactive fill tokens (button/tile backgrounds) ──
    // One source of truth so every panel uses the same hover/active/idle alpha
    // instead of ad-hoc rgba literals scattered across the panels.
    readonly property real  fillActiveAlpha: 0.18
    readonly property real  fillHoverAlpha:  0.10
    readonly property color fillActive:      Qt.rgba(seal.r, seal.g, seal.b, fillActiveAlpha) // selected/active OR ghost-action hover
    readonly property color fillHover:        Qt.rgba(seal.r, seal.g, seal.b, fillHoverAlpha)  // light-seal hover (idle chip → this → fillActive)
    readonly property color fillIdle:         Qt.rgba(0, 0, 0, 0.12)              // resting chip (slight darken)
    // faint, NEUTRAL backdrop behind picker thumbnails — NOT an interactive fill.
    // ink-tinted and much weaker than fillIdle so a thumbnail sits on a quiet frame,
    // not on a dark interactive-looking box.
    readonly property color frameWeak:        Qt.rgba(ink.r, ink.g, ink.b, 0.05)
    readonly property color fillPrimaryHover: Qt.lighter(seal, 1.15)                // solid-seal button hover
    function evenW(w) { return 2 * Math.round(w / 2) }  // even px width -> integer-centered native text (crisp)

    // ── Multi-monitor popup routing ─────────────────────────────
    // Bars exist per screen, but panels remain singletons. The bar under the
    // pointer publishes its screen + local anchor map before any widget opens a
    // popup, so the singleton panel can move to the correct output.
    property var activePopupScreen: null
    property string activePopupScreenName: ""
    property var barAnchorsByScreen: ({})
    property bool _closingPopups: false
    property var barLayoutControllers: ({})
    property bool _barLayoutSyncing: false

    readonly property bool anyPopupVisible: menuVisible || themeSwitcherVisible || wallpaperSwitcherVisible || clipboardVisible || emojiPickerVisible || captureVisible || calendarVisible || cpuVisible || aiUsageVisible
        || memVisible || volVisible || controlVisible || networkVisible || bluetoothVisible
        || batteryVisible || mprisVisible || tailscaleVisible
        || workspaceVisible || imagePickerVisible || mediaBrowserVisible || notifVisible
        || powerProfileVisible || shellUpdateVisible || trayVisible || trayMenuVisible
    readonly property bool keyboardPopupVisible: menuVisible || themeSwitcherVisible || wallpaperSwitcherVisible || clipboardVisible || emojiPickerVisible || captureVisible || imagePickerVisible || mediaBrowserVisible

    function registerBarLayoutController(screenName, controller) {
        if (!screenName || !controller) return

        var next = {}
        for (var screen in barLayoutControllers) next[screen] = barLayoutControllers[screen]
        next[screenName] = controller
        barLayoutControllers = next
    }

    function unregisterBarLayoutController(screenName, controller) {
        if (!screenName) return
        if (controller && barLayoutControllers[screenName] !== controller) return

        var next = {}
        for (var screen in barLayoutControllers) {
            if (screen !== screenName) next[screen] = barLayoutControllers[screen]
        }
        barLayoutControllers = next
    }

    function barLayoutControllerScreenValid(screenName) {
        if (!screenName) return false

        for (var i = 0; i < Quickshell.screens.length; i++) {
            var screen = Quickshell.screens[i]
            if (screen.name === screenName && screen.width > 0 && screen.height > 0) return true
        }
        return false
    }

    function barLayoutControllerKeys() {
        var keys = []
        for (var screen in barLayoutControllers) {
            if (barLayoutControllerScreenValid(screen)) keys.push(screen)
        }
        keys.sort()
        return keys
    }

    function applyToBarLayoutControllers(actionName) {
        var keys = barLayoutControllerKeys()

        _barLayoutSyncing = true
        try {
            for (var i = 0; i < keys.length; i++) {
                var controller = barLayoutControllers[keys[i]]
                if (controller && controller[actionName]) controller[actionName]()
            }
        } finally {
            _barLayoutSyncing = false
        }
    }

    function syncBarSplits(sourceScreenName, serialized) {
        if (_barLayoutSyncing || !serialized) return

        _barLayoutSyncing = true
        try {
            var keys = barLayoutControllerKeys()
            for (var i = 0; i < keys.length; i++) {
                if (keys[i] === sourceScreenName) continue
                var controller = barLayoutControllers[keys[i]]
                if (controller && controller.applySplits) controller.applySplits(serialized)
            }
        } finally {
            _barLayoutSyncing = false
        }
    }

    function syncBarOrder(sourceScreenName, serialized) {
        if (_barLayoutSyncing || !serialized) return

        _barLayoutSyncing = true
        try {
            var keys = barLayoutControllerKeys()
            for (var i = 0; i < keys.length; i++) {
                if (keys[i] === sourceScreenName) continue
                var controller = barLayoutControllers[keys[i]]
                if (controller && controller.applyOrder) controller.applyOrder(serialized)
            }
        } finally {
            _barLayoutSyncing = false
        }
    }

    function splitAllBars() {
        applyToBarLayoutControllers("splitAll")
    }

    function mergeAllBars() {
        applyToBarLayoutControllers("mergeAll")
    }

    function resetAllBarLayouts() {
        applyToBarLayoutControllers("defaultLayout")
    }

    function activatePopupScreen(screen) {
        if (!screen || screen.name === "") return

        activePopupScreen = screen
        activePopupScreenName = screen.name
        applyActiveBarAnchors()
    }

    function activateFocusedPopupScreen() {
        var monitor = Hyprland.focusedMonitor
        var targetName = monitor ? monitor.name : ""

        for (var i = 0; i < Quickshell.screens.length; i++) {
            var candidate = Quickshell.screens[i]
            if (candidate.name === targetName
                    && candidate.width > 0
                    && candidate.height > 0) {
                activatePopupScreen(candidate)
                return true
            }
        }

        if (activePopupScreenName !== "") return true

        for (var j = 0; j < Quickshell.screens.length; j++) {
            var fallback = Quickshell.screens[j]
            if (fallback.name !== ""
                    && fallback.width > 0
                    && fallback.height > 0) {
                activatePopupScreen(fallback)
                return true
            }
        }

        return false
    }

    Connections {
        target: Hyprland

        function onFocusedMonitorChanged() {
            if (!theme.keyboardPopupVisible || theme.activePopupScreenName === "") return

            var monitor = Hyprland.focusedMonitor
            var focusedName = monitor ? monitor.name : ""
            if (focusedName !== "" && focusedName !== theme.activePopupScreenName) {
                theme.closePopups()
            }
        }
    }

    function isActivePopupScreenName(screenName) {
        return activePopupScreenName !== "" && screenName === activePopupScreenName
    }

    function applyAnchor(name, x) {
        if (name === "tray") trayBarX = x
        else if (name === "notif") notifBarX = x
        else if (name === "quickActions") quickActionsBarX = x
        else if (name === "volume") volumeBarX = x
        else if (name === "network") networkBarX = x
        else if (name === "battery") batteryBarX = x
        else if (name === "memory") memoryBarX = x
        else if (name === "cpu") cpuBarX = x
        else if (name === "ai") aiBarX = x
        else if (name === "workspace") workspaceBarX = x
        else if (name === "bluetooth") bluetoothBarX = x
        else if (name === "power") powerBarX = x
        else if (name === "mpris") mprisBarX = x
        else if (name === "launcher") launcherBarX = x
        else if (name === "shellUpdate") shellUpdateBarX = x
        else if (name === "tailscale") tailscaleBarX = x
        else if (name === "trayMenu") trayMenuX = x
    }

    function applyActiveBarAnchors() {
        var anchors = activePopupScreenName ? barAnchorsByScreen[activePopupScreenName] : null
        if (!anchors) return

        for (var name in anchors) applyAnchor(name, anchors[name])
    }

    function publishBarAnchors(screenName, anchors) {
        if (!screenName || !anchors) return

        var next = {}
        for (var screen in barAnchorsByScreen) next[screen] = barAnchorsByScreen[screen]
        next[screenName] = anchors
        barAnchorsByScreen = next

        if (screenName === activePopupScreenName) applyActiveBarAnchors()
    }

    function setPanelAnchor(name, x, screenName) {
        var targetScreen = screenName || activePopupScreenName
        if (targetScreen) {
            var next = {}
            for (var screen in barAnchorsByScreen) next[screen] = barAnchorsByScreen[screen]

            var current = next[targetScreen] || {}
            var anchors = {}
            for (var key in current) anchors[key] = current[key]
            anchors[name] = x
            next[targetScreen] = anchors
            barAnchorsByScreen = next
        }

        if (!targetScreen || targetScreen === activePopupScreenName) applyAnchor(name, x)
    }

    function closePopups(except) {
        _closingPopups = true
        if (except !== "menuVisible") menuVisible = false
        if (except !== "themeSwitcherVisible") themeSwitcherVisible = false
        if (except !== "wallpaperSwitcherVisible") wallpaperSwitcherVisible = false
        if (except !== "clipboardVisible") clipboardVisible = false
        if (except !== "emojiPickerVisible") emojiPickerVisible = false
        if (except !== "captureVisible") captureVisible = false
        if (except !== "calendarVisible") calendarVisible = false
        if (except !== "cpuVisible") cpuVisible = false
        if (except !== "aiUsageVisible") aiUsageVisible = false
        if (except !== "memVisible") memVisible = false
        if (except !== "volVisible") volVisible = false
        if (except !== "controlVisible") controlVisible = false
        if (except !== "networkVisible") networkVisible = false
        if (except !== "bluetoothVisible") bluetoothVisible = false
        if (except !== "batteryVisible") batteryVisible = false
        if (except !== "mprisVisible") mprisVisible = false
        if (except !== "workspaceVisible") workspaceVisible = false
        if (except !== "imagePickerVisible") imagePickerVisible = false
        if (except !== "mediaBrowserVisible") mediaBrowserVisible = false
        if (except !== "notifVisible") notifVisible = false
        if (except !== "powerProfileVisible") powerProfileVisible = false
        if (except !== "shellUpdateVisible") shellUpdateVisible = false
        if (except !== "trayVisible") trayVisible = false
        if (except !== "trayMenuVisible") trayMenuVisible = false
        if (except !== "tailscaleVisible") tailscaleVisible = false
        hideTooltip()
        _closingPopups = false
    }

    function popupOpened(prop) {
        if (!_closingPopups && theme[prop]) closePopups(prop)
    }

    function openImagePicker(mode) {
        activateFocusedPopupScreen()
        mediaBrowserVisible = false
        imagePickerMode = mode
        imagePickerVisible = true
    }

    function openMediaBrowser(mode) {
        activateFocusedPopupScreen()
        imagePickerVisible = false
        mediaBrowserMode = mode
        mediaBrowserVisible = true
    }

    // ── Native Omarchy theme switcher ──
    property bool themeSwitcherVisible: false
    onThemeSwitcherVisibleChanged: popupOpened("themeSwitcherVisible")

    function openThemeSwitcher() {
        activateFocusedPopupScreen()
        themeSwitcherVisible = true
    }

    // ── Native Omarchy wallpaper switcher ──
    property bool wallpaperSwitcherVisible: false
    onWallpaperSwitcherVisibleChanged: popupOpened("wallpaperSwitcherVisible")

    function openWallpaperSwitcher() {
        activateFocusedPopupScreen()
        wallpaperSwitcherVisible = true
    }

    function reloadThemePalette() {
        paletteReader.running = false
        paletteReader.running = true
    }

    function setMonoFont(fontName) {
        var next = String(fontName || "").trim()
        if (next.length > 0) mono = next
    }

    // ── Native Omarchy menu state ──
    property bool menuVisible: false
    property string menuRoute: "root"
    onMenuVisibleChanged: popupOpened("menuVisible")

    function openMenu(route) {
        activateFocusedPopupScreen()
        menuRoute = route || "root"
        menuVisible = true
    }

    property bool clipboardVisible: false
    property var historyDiagnosticsProvider: null
    onClipboardVisibleChanged: popupOpened("clipboardVisible")
    function openClipboard() { activateFocusedPopupScreen(); clipboardVisible = true }

    property bool emojiPickerVisible: false
    onEmojiPickerVisibleChanged: popupOpened("emojiPickerVisible")
    function openEmojiPicker() { activateFocusedPopupScreen(); emojiPickerVisible = true }

    property bool captureVisible: false
    property string captureAction: ""
    onCaptureVisibleChanged: popupOpened("captureVisible")
    function openCapture() { activateFocusedPopupScreen(); captureVisible = true }

    // ── pill/card border (default, non-borderless mode) ──
    // A premium "inactive window border" look: the surface tone (paper) nudged a
    // tick toward the foreground (ink) → a quiet edge a touch brighter than the
    // background, theme-aware in BOTH dark and light palettes. Tune via pillBorderMix.
    property real pillBorderMix: 0.13
    readonly property color pillBorder: Qt.rgba(
        paper.r * (1 - pillBorderMix) + ink.r * pillBorderMix,
        paper.g * (1 - pillBorderMix) + ink.g * pillBorderMix,
        paper.b * (1 - pillBorderMix) + ink.b * pillBorderMix, 1.0)
    // outer frame (the island edge against the wallpaper): a tick brighter than
    // the inner pill border so the bar lifts off the background → two readable
    // borders (subtle inner pills + a defined outer frame).
    property real islandBorderMix: 0.16
    readonly property color islandBorder: Qt.rgba(
        paper.r * (1 - islandBorderMix) + ink.r * islandBorderMix,
        paper.g * (1 - islandBorderMix) + ink.g * islandBorderMix,
        paper.b * (1 - islandBorderMix) + ink.b * islandBorderMix, 1.0)

    // ── bar style tokens (persisted; consumed by every pill/card surface) ──
    // Single source for the pill recipe; consumed by 37 surfaces (12 widgets +
    // 3 group pills + island + 20 cards + tooltip) — change the recipe here once.
    // border on/off and shadow on/off are INDEPENDENT (4 combos possible).
    property bool styleBorder:      true    // pill/card 1px border on/off
    property bool styleShadow:      false   // box-shadow on/off
    property bool styleFrost:       false   // lower bar-island opacity; theme blur may show through
    property bool styleRadiusSmall: false   // radius 12 ⇄ 6
    property bool styleHeightMin:   false   // inner pill 24 ⇄ 20 (slot stays 28)
    readonly property int   pillRadius:   styleRadiusSmall ? 6 : 12
    readonly property int   pillH:        styleHeightMin ? 20 : 24
    readonly property int   pillBorderW:  styleBorder ? 1 : 0
    readonly property int   islandRadius: styleRadiusSmall ? 8 : 16
    readonly property int   tileRadius:   pillRadius - 2   // inner panel buttons: 2 less than global (10 ⇄ 4)
    // horizontal padding of the workspace pill (overhang each side, mirrored by the
    // G2 slot pad). In "numbers" the wide digit badges should nestle concentrically
    // into the pill's inner radius → pad = pillRadius - badgeRadius; else a fixed 4.
    readonly property int   wsPillPad:    workspaceStyle === "numbers"
                                          ? Math.max(1, pillRadius - (styleRadiusSmall ? 5 : 10))
                                          : 4
    readonly property color pillShadow:   Qt.rgba(0, 0, 0, 0.55)   // dark, theme-independent

    property string lastAppliedName: ""

    // ── Tooltip state ──
    property string tooltipText: ""
    property real tooltipX: 0
    property real tooltipY: 0
    property bool tooltipShown: false
    property var tooltipOwner: null   // the widget currently owning the tooltip

    function showTooltip(text, x, y, owner) {
        if (!text) return;
        tooltipText = text;
        tooltipX = x;
        tooltipY = y;
        tooltipOwner = owner !== undefined ? owner : null;
        tooltipShown = true;
    }

    // hide only if the caller owns the current tooltip (owner match is stable
    // even when the tooltip text changes, e.g. a live timer). A null/undefined
    // owner force-hides. Legacy string args fall back to a text match.
    function hideTooltip(owner) {
        if (owner === undefined || owner === null) {
            tooltipShown = false; tooltipOwner = null;
        } else if (typeof owner === "object") {
            if (tooltipOwner === owner) { tooltipShown = false; tooltipOwner = null; }
        } else if (tooltipText === owner) {
            tooltipShown = false; tooltipOwner = null;
        }
    }

    // safety net: if the owning widget disappears while its tooltip is shown
    // (e.g. ScreenRecord stops mid-hover, or a slot widget gets disabled), force-hide.
    // Via Connections — NOT a `_visible` property whose change-handler writes
    // tooltipOwner (that property read tooltipOwner → binding loop).
    Connections {
        target: theme.tooltipOwner
        ignoreUnknownSignals: true
        function onVisibleChanged() {
            if (theme.tooltipOwner && !theme.tooltipOwner.visible) {
                theme.tooltipShown = false; theme.tooltipOwner = null;
            }
        }
    }

    // ── Calendar state ──
    property bool calendarVisible: false
    onCalendarVisibleChanged: popupOpened("calendarVisible")
    property int calendarMonthOffset: 0
    property int calendarTick: 0
    property int selectedDay: 0
    property string selectedCalendarDate: ""
    readonly property date calendarDisplayDate: {
        const now = new Date();
        return new Date(now.getFullYear(), now.getMonth() + calendarMonthOffset, 1);
    }
    readonly property int calendarDisplayYear: calendarDisplayDate.getFullYear()
    readonly property int calendarDisplayMonth: calendarDisplayDate.getMonth()
    readonly property var holidays: holidayService

    function holidayConfigValue(name, fallback) {
        var config = calendarHolidayConfig || {}
        return config[name] !== undefined ? config[name] : fallback
    }

    HolidayService {
        id: holidayService
        enabled: theme.holidayConfigValue("enabled", true) === true
        defaultCountryMode: String(theme.holidayConfigValue("countryMode",
            String(theme.holidayConfigValue("country", "auto")).toLowerCase() === "auto" ? "auto" : "manual"))
        defaultCountry: String(theme.holidayConfigValue("country", ""))
        defaultSubdivision: String(theme.holidayConfigValue("subdivision", ""))
        defaultShowNational: theme.holidayConfigValue("showNational", true) !== false
        defaultShowRegional: theme.holidayConfigValue("showRegional", true) !== false
        defaultRegionalExplicit: (theme.calendarHolidayConfig || {}).showRegional !== undefined
        showInGrid: theme.holidayConfigValue("showInGrid", true) === true
        panelVisible: theme.calendarVisible
        displayedYear: theme.calendarDisplayYear
    }

    function localIsoDate(year, month, day) {
        if (day < 1) return ""
        return String(year).padStart(4, "0") + "-"
            + String(month + 1).padStart(2, "0") + "-"
            + String(day).padStart(2, "0")
    }

    function calendarIsoDate(day) {
        return localIsoDate(calendarDisplayYear, calendarDisplayMonth, day)
    }

    readonly property var calendarCells: {
        calendarTick;
        const now = new Date();
        const first = calendarDisplayDate;
        const year = first.getFullYear();
        const month = first.getMonth();
        const lastDay = new Date(year, month + 1, 0).getDate();
        const startDay = first.getDay();
        const today = new Date();
        const isCurrentMonth = year === today.getFullYear() && month === today.getMonth();
        const cells = [];
        for (let i = 0; i < startDay; i++) cells.push({day: 0, today: false});
        for (let d = 1; d <= lastDay; d++) {
            cells.push({day: d, today: isCurrentMonth && d === today.getDate()});
        }
        while (cells.length < 42) cells.push({day: 0, today: false});
        return cells;
    }

    readonly property string calendarMonthName: {
        const months = ["JANUARY","FEBRUARY","MARCH","APRIL","MAY","JUNE",
                        "JULY","AUGUST","SEPTEMBER","OCTOBER","NOVEMBER","DECEMBER"];
        const now = new Date();
        return months[(now.getMonth() + calendarMonthOffset + 12000) % 12];
    }

    readonly property string calendarYear: {
        return String(calendarDisplayYear);
    }

    function openCalendar() {
        activateFocusedPopupScreen();
        calendarMonthOffset = 0;
        calendarTick++;
        const today = new Date();
        selectedDay = today.getDate();
        selectedCalendarDate = localIsoDate(today.getFullYear(), today.getMonth(), selectedDay);
        calendarVisible = true;
    }

    // ── CPU panel state ──
    property bool cpuVisible: false
    onCpuVisibleChanged: popupOpened("cpuVisible")
    property bool systemMetricsReady: false
    property bool networkServiceReady: false
    readonly property var systemMetrics: systemMetricsService

    SystemMetricsService {
        id: systemMetricsService
        enabled: theme.systemMetricsReady
        panelVisible: theme.cpuVisible
    }

    readonly property var network: networkService
    NetworkSummaryService {
        id: networkService
        enabled: theme.networkServiceReady
        panelVisible: theme.networkVisible
    }

    // ── AI usage panel state + which tool the bar pill shows ──
    property bool   aiUsageVisible: false
    onAiUsageVisibleChanged: {
        popupOpened("aiUsageVisible")
        if (aiUsageVisible) refreshAiUsage()
    }
    property string aiTool: "codex"   // "claude", "codex", or "opencode" — icon shown in the bar
    property bool aiCollectorReady: false
    readonly property var aiUsage: aiUsageService
    readonly property string aiClStatus: aiUsageService.aiClStatus
    readonly property string aiCxStatus: aiUsageService.aiCxStatus
    readonly property string aiOcStatus: aiUsageService.aiOcStatus
    readonly property string aiClMessage: aiUsageService.aiClMessage
    readonly property string aiCxMessage: aiUsageService.aiCxMessage
    readonly property string aiOcMessage: aiUsageService.aiOcMessage
    readonly property string aiClCollectedAt: aiUsageService.aiClCollectedAt
    readonly property string aiCxCollectedAt: aiUsageService.aiCxCollectedAt
    readonly property string aiOcCollectedAt: aiUsageService.aiOcCollectedAt

    AiUsageService {
        id: aiUsageService
        startupReady: theme.aiCollectorReady
        panelVisible: theme.aiUsageVisible
        selectedTool: theme.aiTool
        onProviderDataChanged: theme.syncAiUsageFields()
        onAiClockTickChanged: {
            theme.aiClockTick = aiClockTick
            theme.syncAiUsageFields()
        }
        Component.onCompleted: theme.syncAiUsageFields()
    }

    function syncAiUsageFields() {
        aiClHas = aiUsageService.aiClHas
        aiClFresh = aiUsageService.aiClFresh
        aiClPct5h = aiUsageService.aiClPct5h
        aiClPct7d = aiUsageService.aiClPct7d
        aiClBlocked = aiUsageService.aiClBlocked
        aiClTokens = aiUsageService.aiClTokens
        aiClRate = aiUsageService.aiClRate
        aiClReset5hTs = aiUsageService.aiClReset5hTs
        aiClReset7dTs = aiUsageService.aiClReset7dTs
        aiClToday = aiUsageService.aiClToday
        aiCxHas = aiUsageService.aiCxHas
        aiCxFresh = aiUsageService.aiCxFresh
        aiCxState = aiUsageService.aiCxState
        aiCxHas5h = aiUsageService.aiCxHas5h
        aiCxHasWeekly = aiUsageService.aiCxHasWeekly
        aiCxPct5h = aiUsageService.aiCxPct5h
        aiCxPct7d = aiUsageService.aiCxPct7d
        aiCxPlan = aiUsageService.aiCxPlan
        aiCxCreditsAvailable = aiUsageService.aiCxCreditsAvailable
        aiCxCredits = aiUsageService.aiCxCredits
        aiCxTokens = aiUsageService.aiCxTokens
        aiCxRate = aiUsageService.aiCxRate
        aiCxReset5hTs = aiUsageService.aiCxReset5hTs
        aiCxReset7dTs = aiUsageService.aiCxReset7dTs
        aiCxToday = aiUsageService.aiCxToday
        aiOcHas = aiUsageService.aiOcHas
        aiOcFresh = aiUsageService.aiOcFresh
        aiOcPct5h = aiUsageService.aiOcPct5h
        aiOcPct7d = aiUsageService.aiOcPct7d
        aiOcPlan = aiUsageService.aiOcPlan
        aiOcTokens = aiUsageService.aiOcTokens
        aiOcRate = aiUsageService.aiOcRate
        aiOcModel = aiUsageService.aiOcModel
        aiOcToday = aiUsageService.aiOcToday
        aiOcModels = aiUsageService.aiOcModels
    }

    // ── AI usage data (single source of truth) ───────────────────
    // The bar pill (ClaudeWidget) and the AiUsagePanel both render from these —
    // the cache parsing lives ONLY here so the two views can never drift apart.
    // Token strings are bare "X.XXM / Y.YM"; the pill tooltip appends " tokens".
    property bool   aiClHas: false
    property bool   aiClFresh: false
    property int    aiClPct5h: 0
    property int    aiClPct7d: 0
    property bool   aiClBlocked: false
    property string aiClTokens: ""
    property string aiClRate: ""
    property int    aiClReset5hTs: 0
    property int    aiClReset7dTs: 0
    property int    aiClToday: 0

    property bool   aiCxHas: false
    property bool   aiCxFresh: false
    property string aiCxState: "stale"
    property bool   aiCxHas5h: false
    property bool   aiCxHasWeekly: false
    property int    aiCxPct5h: 0
    property int    aiCxPct7d: 0
    property string aiCxPlan: ""
    property bool   aiCxCreditsAvailable: false
    property string aiCxCredits: ""
    property string aiCxTokens: ""
    property string aiCxRate: ""
    property int    aiCxReset5hTs: 0
    property int    aiCxReset7dTs: 0
    property int    aiCxToday: 0

    property bool   aiOcHas: false
    property bool   aiOcFresh: false
    property int    aiOcPct5h: 0
    property int    aiOcPct7d: 0
    property string aiOcPlan: ""
    property string aiOcTokens: ""
    property string aiOcRate: ""
    property string aiOcModel: ""
    property int    aiOcToday: 0
    property var    aiOcModels: []
    property int    aiClockTick: 0
    property real   aiLastBackendKick: 0

    // F15: clamp an external 0..1 utilization to a 0–100 int (a negative/over-range value would
    // otherwise produce wrong text and negative/overwide usage bars)
    function aiPct(v) { return Math.max(0, Math.min(100, Math.round((parseFloat(v) || 0) * 100))) }

    function aiFmtReset(ts) {
        aiClockTick
        var now = Date.now() / 1000
        if (!(ts > now)) return ""
        var mins = Math.round((ts - now) / 60)
        if (mins < 60) return mins + "m"
        var h = Math.floor(mins / 60), m = mins % 60
        if (h < 24) return h + "h " + m + "m"
        var d = Math.floor(h / 24); return d + "d " + (h % 24) + "h"
    }

    function aiFmtResetAt(ts) {
        if (!(ts > 0)) return ""
        return new Date(ts * 1000).toLocaleString(Qt.locale(), "MMM d, yyyy h:mm AP")
    }

    function refreshAiUsage(selectedOnly, skipBackendKick) {
        aiUsageService.refreshAiUsage(selectedOnly, skipBackendKick)
    }

    function forceAiUsageRefresh(selectedOnly) {
        return aiUsageService.refresh(selectedOnly === true, true)
    }

    function aiUsageDiagnosticObject() {
        return aiUsageService.diagnosticObject()
    }

    Timer {
        // Legacy cache readers above remain inert for migration compatibility;
        // AiUsageService is the only collector and parser.
        interval: 60000
        running: false
        repeat: false
    }

    // ── Memory panel state ──
    property bool memVisible: false
    onMemVisibleChanged: popupOpened("memVisible")

    // ── Volume panel state ──
    property bool volVisible: false
    onVolVisibleChanged: popupOpened("volVisible")

    // ── Control center state ──
    property bool controlVisible: false
    onControlVisibleChanged: {
        popupOpened("controlVisible")
        if (!controlVisible) { splitsSubVisible = false; wwSubVisible = false }
    }

    // ── Split state (controlled by Bar + ControlPanel) ──
    property bool splitLeft:   false
    property bool splitRight:  false
    property bool splitArch:   false
    property bool splitMon:    false
    property bool splitNet:    false
    property bool splitMprisL: false
    // Gap animation mode. 20..32 are the current named modes; 1..8 remain
    // readable so older caches can be migrated without corrupting the file.
    property int barAnim: 0

    // ── Bar layout / unlock (drag&drop reorder). barUnlocked is transient. ──
    property bool barUnlocked: false
    // split-control hooks called by the ControlPanel split sub-panel.
    property var  fnSplitAll:      function () { theme.splitAllBars() }
    property var  fnMergeAll:      function () { theme.mergeAllBars() }
    property var  fnDefaultLayout: function () { theme.resetAllBarLayouts() }
    property bool splitsSubVisible: false
    property bool wwSubVisible: false   // "Widgets & Workspaces" fly-out

    // Legacy split booleans are kept only for cache compatibility. The active
    // split system lives in BarSlot's per-gap arrays; ParticleStream is gated by
    // the real run count there, so barAnim no longer follows these old flags.
    function mergeAllSplits() {
        splitLeft = false; splitRight = false; splitArch = false;
        splitMon = false; splitNet = false; splitMprisL = false;
    }

    // ── Control-panel state persistence (splits / anim / accent) ──
    // Survives bar restarts via a tiny cache file; no extra deps (same Process+cat
    // pattern used elsewhere). _splitsLoaded gates saving so the initial restore
    // doesn't immediately write back over itself.
    readonly property string splitsCachePath: Quickshell.env("HOME") + "/.cache/quickshell_splits"
    property bool _splitsLoaded: false

    onSplitArchChanged:      if (_splitsLoaded) saveSplits()
    onSplitMonChanged:       if (_splitsLoaded) saveSplits()
    onSplitNetChanged:       if (_splitsLoaded) saveSplits()
    onSplitMprisLChanged:    if (_splitsLoaded) saveSplits()
    onBarAnimChanged:        if (_splitsLoaded) saveSplits()
    onBarColorChanged:       if (_splitsLoaded) saveSplits()

    // Build the command imperatively (not as a binding): a bound `command` can
    // still hold the pre-toggle value when the Process runs, saving stale state.
    function saveSplits() {
        var line = (splitArch   ? "1" : "0") + " "
                 + (splitMon     ? "1" : "0") + " "
                 + (splitMprisL  ? "1" : "0") + " "
                 + (splitNet     ? "1" : "0") + " "
                 + barAnim + " "
                 + barColor
        splitSaveProc.command = ["bash", "-c",
            "mkdir -p \"$(dirname '" + splitsCachePath + "')\" && echo '" + line + "' > '" + splitsCachePath + "'"]
        splitSaveProc.running = false
        splitSaveProc.running = true
    }

    Process {
        id: splitLoadProc
        command: ["cat", theme.splitsCachePath]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                var parts = this.text.trim().split(" ")
                if (parts.length >= 5) {
                    theme.splitArch      = parts[0] === "1"
                    theme.splitMon       = parts[1] === "1"
                    theme.splitMprisL    = parts[2] === "1"
                    theme.splitNet       = parts[3] === "1"
                    var ba = parseInt(parts[4])
                    // Preserve "off" and current named modes. Map the former
                    // effects to their closest replacement on first load.
                    var legacyGapModes = [0, 24, 25, 26, 26, 24, 25, 28, 27]
                    if (ba >= 0 && ba <= 8) theme.barAnim = legacyGapModes[ba]
                    else theme.barAnim = (ba >= 20 && ba <= 32) ? ba : 0
                    if (parts.length >= 6) {
                        var bc = parts[5]
                        if (bc === "1") theme.barColor = "red"
                        else if (bc === "0") theme.barColor = "red"
                        else if (bc === "green" || bc === "color2") theme.barColor = "red"
                        else if (bc === "yellow" || bc === "color3") theme.barColor = "red"
                        else if (bc === "accent" || bc === "color02" || bc === "color03") theme.barColor = "red"
                        else if (bc === "cat_mauve") theme.barColor = "mauve"
                        else if (bc === "cat_pink") theme.barColor = "purple"
                        else if (bc === "cat_blue" || bc === "tokyo_blue") theme.barColor = "blue"
                        else if (bc.indexOf("cat_") === 0 || bc.indexOf("tokyo_") === 0) theme.barColor = "red"
                        else if (theme.barColorValid(bc)) theme.barColor = bc
                    }
                }
                theme._splitsLoaded = true
            }
        }
    }

    Process { id: splitSaveProc }   // command is set imperatively in saveSplits()

    // ── module enable flags (controlled by ControlPanel) ──
    property bool modStatus:     true
    property bool modMemory:     true
    property bool modCpu:        true
    property bool modVolume:     true
    property bool modNetwork:    true
    readonly property string networkMode: networkService.connectionType
    readonly property real networkDlRate: networkService.receiveRateBytes
    readonly property real networkUlRate: networkService.transmitRateBytes
    property bool omarchyUpdateAvail: false   // mirrored from UpdateWidget (6h poll)
    property bool notifSilenced: false        // mirrored from NotificationSilenceWidget (DND)
    property string notifLatestSummary: ""
    property string notifLatestBody: ""
    property string notifLatestApp: ""
    property var notifLatestObject: null
    property int notifSerial: 0
    property bool modNotifications: true      // notification bell inside the status group
    property string voxState: "idle"          // mirrored from VoxtypeWidget: idle/recording/transcribing
    property bool mprisActive: false          // mirrored from MprisWidget; keeps active media visible in compact layouts
    readonly property bool mprisPlaying: mediaSelection.playing // true only while a real MPRIS player is playing
    property var mprisPausedPlayers: []     // recent players paused through the bar

    function rememberMprisPausedPlayer(player) {
        if (!player) return
        var next = []
        for (var i = 0; i < mprisPausedPlayers.length; i++)
            if (mprisPausedPlayers[i] !== player) next.push(mprisPausedPlayers[i])
        next.push(player)
        mprisPausedPlayers = next
    }

    function forgetMprisPausedPlayer(player) {
        if (!player) return
        var next = []
        for (var i = 0; i < mprisPausedPlayers.length; i++)
            if (mprisPausedPlayers[i] !== player) next.push(mprisPausedPlayers[i])
        mprisPausedPlayers = next
    }
    property bool codexActive: false          // mirrored from ClaudeWidget's Codex process probe
    // battery presence (laptop) — drives the Battery indicator tile's visibility.
    // Direct UPower check, event-driven.
    readonly property bool hasBattery: UPower.displayDevice !== null && UPower.displayDevice.isLaptopBattery
    // NetworkManager active (Omarchy 4.0) → the panel's iwctl scan/connect won't work,
    // so it shows an "open nmtui" button instead of an empty list
    property bool useNM: false
    Process {
        command: ["bash", "-c", "systemctl is-active --quiet NetworkManager && echo 1 || echo 0"]
        running: true
        stdout: StdioCollector { onStreamFinished: theme.useNM = this.text.trim() === "1" }
    }

    // ── wifi/bluetooth settings launchers (Omarchy way, via uwsm-app) ──
    // iwd (Omarchy 3.8.x) → impala/bluetui through omarchy-launch-*; if NetworkManager
    // is the active backend (Omarchy 4.0) → nmtui instead.
    readonly property string launchWifiCmd: "if systemctl is-active --quiet NetworkManager 2>/dev/null; then omarchy-launch-or-focus-tui nmtui; else omarchy-launch-wifi; fi"
    readonly property string launchBtCmd:   "omarchy-launch-bluetooth"
    property bool modPower:      false   // default off (toggle in ControlPanel)
    property bool modBluetooth:  true    // Bluetooth pill inside the network/privacy group
    property bool modMedia:      true
    property bool modQuick:      true    // G10 group pill (idle-inhibitor · media · theme)
    property bool modMpris:      true    // G9 now-playing / mpris pill
    property bool modClaude:     true    // default on (toggle in ControlPanel)
    property bool aiUsageManual: false  // user explicitly enabled the AI pill
    property bool modPrivacy:    true    // microphone/camera privacy pills
    property bool modPrivacyMic: true
    property bool modPrivacyCamera: true
    property bool modBattery:    true    // battery pill, shown only when hardware exists
    property bool modClock:      true    // center clock/date pill
    property bool modTailscale:  false   // optional Tailscale status pill; default off
    property bool volumeManual:  false   // user explicitly enabled the volume pill

    TailscaleService {
        id: tailscaleService
        settings: ({})
    }
    readonly property var tailscale: tailscaleService
    readonly property bool tailscaleAvailable: tailscaleService.installed
    readonly property string tailscaleStatus: tailscaleService.statusText
    readonly property string tailscaleHostName: tailscaleService.selfName
    readonly property string tailscaleAddress: tailscaleService.selfIp
    readonly property string tailscaleTailnet: tailscaleService.selectedAccountLabel || tailscaleService.selfDnsName || ""
    readonly property string tailscaleBackendState: tailscaleService.backendState
    readonly property int tailscalePeerCount: tailscaleService.peers.length

    function refreshTailscale() {
        tailscaleService.refresh(true)
    }

    // ── Quickshell transient OSD ───────────────────────────────
    property bool mediaTrackNotificationsReady: false
    property string lastMediaTrackKey: ""
    readonly property string observedMediaTrackKey: {
        var player = mediaSelection.player
        if (!player || !player.trackTitle) return ""
        return String(player.dbusName || player.identity || "player") + "\u001f"
            + String(player.trackTitle || "") + "\u001f" + String(player.trackArtist || "")
    }
    onObservedMediaTrackKeyChanged: scheduleMediaTrackNotification()

    function currentMediaTrackKey() {
        return observedMediaTrackKey
    }

    function scheduleMediaTrackNotification() {
        if (!mediaTrackNotificationsReady) {
            lastMediaTrackKey = currentMediaTrackKey()
            return
        }
        mediaTrackChangeTimer.restart()
    }

    Timer {
        id: mediaTrackArmTimer
        interval: 750
        onTriggered: {
            theme.lastMediaTrackKey = theme.currentMediaTrackKey()
            theme.mediaTrackNotificationsReady = true
        }
    }

    Timer {
        id: mediaTrackChangeTimer
        interval: 100
        onTriggered: {
            var player = mediaSelection.player
            var key = theme.currentMediaTrackKey()
            if (!player || key === "" || key === theme.lastMediaTrackKey) return
            theme.lastMediaTrackKey = key
            var title = String(player.trackTitle || "Media")
            var artist = String(player.trackArtist || "")
            theme.showHardwareOsd("media", "", title + (artist ? "\n" + artist : ""), "󰎈", "")
        }
    }

    property bool osdVisible: false
    property string osdKind: ""
    property string osdValue: ""
    property string osdDetail: ""
    property string osdIcon: ""
    property string osdScreenName: ""
    property int osdSerial: 0
    function showHardwareOsd(kind, value, detail, icon, screenName) {
        var nextKind = kind || "status"
        var nextDetail = detail || ""
        if (nextKind === "media" && osdVisible && osdKind === "media" && osdDetail === nextDetail) return
        osdKind = nextKind
        osdValue = value === undefined ? "" : String(value)
        osdDetail = nextDetail
        osdIcon = icon || ""
        if (screenName) osdScreenName = screenName
        else { activateFocusedPopupScreen(); osdScreenName = activePopupScreenName }
        osdVisible = true
        osdSerial++
    }
    Timer { id: osdDismissTimer; interval: 1200; onTriggered: theme.osdVisible = false }
    onOsdSerialChanged: osdDismissTimer.restart()

    readonly property bool volumeWidgetVisible: modVolume && mprisPlaying
    readonly property bool aiWidgetVisible:     modClaude && (aiUsageManual || codexActive)

    function toggleVolumeWidget() {
        // This controls whether the automatic playback-triggered pill is
        // enabled; playback itself controls whether it is currently visible.
        modVolume = !modVolume
    }
    function toggleAiWidget() {
        if (aiWidgetVisible) modClaude = false
        else { modClaude = true; aiUsageManual = true }
    }

    // ── workspace display mode ──
    property string workspaceMode: "10"   // "10", "5", "active"
    // ── workspace display style (orthogonal to mode; persisted) ──
    property string workspaceStyle: "default"   // "default", "numbers", "magic"

    // ── bar screen position (persisted) ──
    property string barPosition: "top"   // "top" or "bottom"

    // ── picker visual style (theme/wallpaper/screenshot/video pickers) ──
    property string pickerStyle: "tanzaku"   // "tanzaku", "hearthstone", "carousel"
    property string launcherLogoMode: "text"     // "text" or "icon"
    property string launcherLogoText: "omarchy"  // "omarchy", "hyprland", "arch", or "omacom"
    property string launcherLogoIcon: "omarchy"  // see launcherLogoIconGlyph()
    property bool   clock12h:        false   // false = 24h, true = 12h (AM/PM)

    // ── widget/workspace state persistence ──
    readonly property string widgetsCachePath: Quickshell.env("HOME") + "/.cache/quickshell_widgets"
    property bool _widgetsLoaded: false

    onModMemoryChanged:     if (_widgetsLoaded) saveWidgets()
    onModClaudeChanged:     if (_widgetsLoaded) saveWidgets()
    onModPowerChanged:      if (_widgetsLoaded) saveWidgets()
    onModBluetoothChanged:  if (_widgetsLoaded) saveWidgets()
    onModNetworkChanged:    if (_widgetsLoaded) saveWidgets()
    onModStatusChanged:     if (_widgetsLoaded) saveWidgets()
    onModNotificationsChanged: {
        if (!modNotifications) notifVisible = false
        if (!modNotifications) trayVisible = false
        if (!modNotifications) trayMenuVisible = false
        if (_widgetsLoaded) saveWidgets()
    }
    onModQuickChanged:      if (_widgetsLoaded) saveWidgets()
    onModCpuChanged:        if (_widgetsLoaded) saveWidgets()
    onModVolumeChanged:     if (_widgetsLoaded) saveWidgets()
    onVolumeManualChanged:  if (_widgetsLoaded) saveWidgets()
    onAiUsageManualChanged: if (_widgetsLoaded) saveWidgets()
    onModMprisChanged:      if (_widgetsLoaded) saveWidgets()
    onModPrivacyChanged:    if (_widgetsLoaded) saveWidgets()
    onModPrivacyMicChanged: if (_widgetsLoaded) saveWidgets()
    onModPrivacyCameraChanged: if (_widgetsLoaded) saveWidgets()
    onModBatteryChanged:    if (_widgetsLoaded) saveWidgets()
    onModClockChanged: {
        if (!modClock) calendarVisible = false
        if (_widgetsLoaded) saveWidgets()
    }
    onModTailscaleChanged: {
        if (modTailscale) refreshTailscale()
        if (_widgetsLoaded) saveWidgets()
    }
    onAiToolChanged:        if (_widgetsLoaded) saveWidgets()
    onWorkspaceModeChanged: if (_widgetsLoaded) saveWidgets()
    onPickerStyleChanged:   if (_widgetsLoaded) saveWidgets()
    onLauncherLogoModeChanged: if (_widgetsLoaded) saveWidgets()
    onLauncherLogoTextChanged: if (_widgetsLoaded) saveWidgets()
    onLauncherLogoIconChanged: if (_widgetsLoaded) saveWidgets()
    onClock12hChanged:        if (_widgetsLoaded) saveWidgets()
    onStyleBorderChanged:      if (_widgetsLoaded) saveWidgets()
    onStyleShadowChanged:      if (_widgetsLoaded) saveWidgets()
    onStyleFrostChanged:       if (_widgetsLoaded) saveWidgets()
    onStyleRadiusSmallChanged: if (_widgetsLoaded) saveWidgets()
    onWorkspaceStyleChanged:   if (_widgetsLoaded) saveWidgets()
    onBarPositionChanged:      if (_widgetsLoaded) saveWidgets()
    function saveWidgets() {
        var line = (modMemory    ? "1" : "0") + " "
                 + "0 "                                  // legacy brightness field; module removed
                 + (modClaude    ? "1" : "0") + " "
                 + (modPower     ? "1" : "0") + " "
                 + (modBluetooth ? "1" : "0") + " "
                 + workspaceMode + " "
                 + pickerStyle + " "
                 + "0 "                                  // legacy weather unit field; weather removed
                 + (clock12h        ? "1" : "0") + " "
                 + (modNetwork      ? "1" : "0") + " "
                 + (styleShadow      ? "1" : "0") + " "   // field +5 (was styleBorderless; value-compatible)
                 + (styleRadiusSmall ? "1" : "0") + " "
                 + (styleHeightMin   ? "1" : "0") + " "
                 + workspaceStyle + " "
                 + barPosition + " "
                 + (styleBorder      ? "1" : "0") + " "   // +10 (new; old caches → derived from styleShadow)
                 + (modStatus ? "1" : "0") + " "          // +11 group pill: status (arch/tray/notif)
                 + (modQuick  ? "1" : "0") + " "          // +12 group pill: quick (idle/media/theme)
                 + (modCpu    ? "1" : "0") + " "          // +13
                 + (modVolume ? "1" : "0") + " "          // +14
                 + (modMpris  ? "1" : "0") + " "          // +15 now-playing / mpris
                 + aiTool + " "                           // +16 AI tool shown in bar (claude/codex/opencode)
                 + (styleFrost ? "1" : "0") + " "         // +17 frost / lowered island opacity
                 + launcherLogoMode + " "                 // +18 launcher logo mode (text/icon)
                 + launcherLogoText + " "                 // +19 text logo id
                 + launcherLogoIcon + " "                 // +20 icon logo id
                 + "0 0 friday 0 "                        // +21..+24 retired package-updater fields
                 + (modPrivacy ? "1" : "0") + " "         // +25 microphone/camera privacy pills
                 + (modBattery ? "1" : "0") + " "         // +26 battery pill
                 + (modPrivacyMic ? "1" : "0") + " "      // +27 microphone privacy pill
                 + (modPrivacyCamera ? "1" : "0") + " "   // +28 camera privacy pill
                 + (modClock ? "1" : "0") + " "            // +29 clock/date pill
                 + "0 "                                    // +30 reserved cache field
                 + "0 "                                    // +31 reserved (legacy Pulse)
                 + (modNotifications ? "1" : "0") + " "   // +32 notification bell
                 + (volumeManual ? "1" : "0") + " "       // +33 volume manual override
                 + (aiUsageManual ? "1" : "0") + " "      // +34 AI manual override
                 + (modTailscale ? "1" : "0")              // +35 optional Tailscale widget
        widgetSaveProc.command = ["bash", "-c",
            "echo '" + line + "' > '" + widgetsCachePath + "'"]
        widgetSaveProc.running = false
        widgetSaveProc.running = true
    }

    readonly property var launcherLogoTextOptions: ["omarchy", "hyprland", "arch", "omacom"]
    readonly property var launcherLogoIconOptions: ["omarchy", "hyprland", "arch", "grid", "spark", "power", "dragon", "mark", "nix", "branch"]

    function launcherLogoTextIndex(id) {
        for (var i = 0; i < launcherLogoTextOptions.length; i++)
            if (launcherLogoTextOptions[i] === id) return i
        return 0
    }
    function launcherLogoIconIndex(id) {
        for (var i = 0; i < launcherLogoIconOptions.length; i++)
            if (launcherLogoIconOptions[i] === id) return i
        return 0
    }
    function launcherLogoTextValid(id) {
        return launcherLogoTextIndex(id) >= 0 && launcherLogoTextOptions[launcherLogoTextIndex(id)] === id
    }
    function launcherLogoIconValid(id) {
        return launcherLogoIconIndex(id) >= 0 && launcherLogoIconOptions[launcherLogoIconIndex(id)] === id
    }
    function nextLauncherLogoText() {
        launcherLogoText = launcherLogoTextOptions[(launcherLogoTextIndex(launcherLogoText) + 1) % launcherLogoTextOptions.length]
    }
    function nextLauncherLogoIcon() {
        launcherLogoIcon = launcherLogoIconOptions[(launcherLogoIconIndex(launcherLogoIcon) + 1) % launcherLogoIconOptions.length]
    }
    function launcherConfigValue(config, a, b, c) {
        if (!config) return undefined
        if (config[a] !== undefined) return config[a]
        if (b && config[b] !== undefined) return config[b]
        if (c && config[c] !== undefined) return config[c]
        return undefined
    }
    function applyLauncherConfig(config) {
        if (!config) return

        var launcher = config.launcher || config.logo || config
        var mode = launcherConfigValue(launcher, "launcherLogoMode", "logoMode", "mode")
        var text = launcherConfigValue(launcher, "launcherLogoText", "textLogo", "text")
        var icon = launcherConfigValue(launcher, "launcherLogoIcon", "iconLogo", "icon")

        if (mode === "text" || mode === "icon") launcherLogoMode = mode
        if (text !== undefined && launcherLogoTextValid(text)) launcherLogoText = text
        if (icon !== undefined && launcherLogoIconValid(icon)) launcherLogoIcon = icon
    }
    function launcherLogoLabel(id) {
        if (id === "omarchy") return "Omarchy"
        if (id === "hyprland") return "Hyprland"
        if (id === "arch") return "Arch"
        if (id === "omacom") return "Omacom"
        if (id === "grid") return "Grid"
        if (id === "spark") return "Spark"
        if (id === "power") return "Power"
        if (id === "dragon") return "Dragon"
        if (id === "mark") return "Mark"
        if (id === "nix") return "Nix"
        if (id === "branch") return "Branch"
        return "Omarchy"
    }
    function launcherLogoIconGlyph(id) {
        if (id === "omarchy") return String.fromCodePoint(0xE900)
        if (id === "hyprland") return ""
        if (id === "arch") return ""
        if (id === "grid") return ""
        if (id === "spark") return ""
        if (id === "power") return ""
        if (id === "dragon") return "⻯"
        if (id === "mark") return ""
        if (id === "nix") return ""
        if (id === "branch") return ""
        return String.fromCodePoint(0xE900)
    }
    function launcherLogoIconFont(id) {
        return id === "omarchy" ? "omarchy" : mono
    }
    function launcherLogoIconSize(id) {
        if (id === "omarchy") return 15
        if (id === "arch") return 17
        if (id === "dragon") return 16
        return 16
    }
    function launcherLogoIconXOffset(id) {
        if (id === "omarchy") return 0.5
        if (id === "hyprland") return 0
        if (id === "arch") return 1
        if (id === "grid") return -1
        if (id === "spark") return 0
        if (id === "power") return 0
        if (id === "dragon") return 0
        if (id === "mark") return 0.5
        if (id === "nix") return 0
        if (id === "branch") return 0
        return 0
    }
    function launcherLogoIconYOffset(id) {
        if (id === "omarchy") return 0
        if (id === "hyprland") return 0
        if (id === "arch") return 0
        if (id === "mark") return 0.5
        if (id === "branch") return 0
        if (id === "dragon") return 0
        return 0
    }

    Process {
        id: widgetLoadProc
        command: ["cat", theme.widgetsCachePath]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                var parts = this.text.trim().split(" ")
                if (parts.length >= 4) {
                    theme.modMemory    = parts[0] !== "0"
                    theme.modClaude    = parts[2] !== "0"
                    theme.modPower     = parts[3] !== "0"
                }
                // parts[4] is the bluetooth flag in the new format, but in the OLD
                // format it was the workspace mode ("10"/"5"/"active") — detect which.
                var wsField = -1
                if (parts.length >= 5) {
                    if (parts[4] === "5" || parts[4] === "active" || parts[4] === "10") {
                        wsField = 4                         // old format: no bluetooth field
                    } else {
                        theme.modBluetooth = parts[4] !== "0"
                        wsField = 5
                    }
                }
                if (wsField >= 0 && parts.length > wsField) {
                    var m = parts[wsField]
                    theme.workspaceMode = (m === "5" || m === "active") ? m : "10"
                    // pickerStyle is the field right after the workspace mode
                    if (parts.length > wsField + 1) {
                        var ps = parts[wsField + 1]
                        if (ps === "hearthstone" || ps === "carousel" || ps === "tanzaku")
                            theme.pickerStyle = ps
                    }
                    // wsField+2 is the legacy weather unit field; weather was removed.
                    if (parts.length > wsField + 3) theme.clock12h        = parts[wsField + 3] === "1"
                    if (parts.length > wsField + 4) theme.modNetwork      = parts[wsField + 4] === "1"
                    // style tokens — appended after modNetwork, each guarded
                    if (parts.length > wsField + 5) theme.styleShadow      = parts[wsField + 5] === "1"
                    if (parts.length > wsField + 6) theme.styleRadiusSmall = parts[wsField + 6] === "1"
                    // field wsField+7 (styleHeightMin) is reserved for offset
                    // stability only — the Height toggle was removed (plan §1.4), so
                    // it is intentionally NOT parsed: a stray "1" must not shrink pills
                    // when there is no UI to undo it. (saveWidgets still writes "0".)
                    if (parts.length > wsField + 8) {
                        var wss = parts[wsField + 8]
                        if (wss === "numbers" || wss === "magic" || wss === "default")
                            theme.workspaceStyle = wss
                    }
                    if (parts.length > wsField + 9) {
                        var bp = parts[wsField + 9]
                        if (bp === "top" || bp === "bottom") theme.barPosition = bp
                    }
                    // +10 styleBorder (independent border on/off). Old caches lack it →
                    // migrate from the old coupled meaning: border = NOT shadow.
                    // Default-true → parse "!== 0" so a corrupted token keeps borders ON.
                    if (parts.length > wsField + 10) theme.styleBorder = parts[wsField + 10] !== "0"
                    else if (parts.length > wsField + 5) theme.styleBorder = !theme.styleShadow
                    // +11..+15 widget-group toggles (default ON → only an explicit "0"
                    // hides; old caches lack these fields → groups stay visible)
                    if (parts.length > wsField + 11) theme.modStatus = parts[wsField + 11] !== "0"
                    if (parts.length > wsField + 12) theme.modQuick  = parts[wsField + 12] !== "0"
                    if (parts.length > wsField + 13) theme.modCpu    = parts[wsField + 13] !== "0"
                    if (parts.length > wsField + 14) theme.modVolume = parts[wsField + 14] !== "0"
                    if (parts.length > wsField + 15) theme.modMpris  = parts[wsField + 15] !== "0"
                    if (parts.length > wsField + 16) {
                        var at = parts[wsField + 16]
                        if (at === "claude" || at === "codex" || at === "opencode") theme.aiTool = at
                    }
                    if (parts.length > wsField + 17) theme.styleFrost = parts[wsField + 17] === "1"
                    if (parts.length > wsField + 18) {
                        var lm = parts[wsField + 18]
                        if (lm === "text" || lm === "icon") {
                            theme.launcherLogoMode = lm
                            if (parts.length > wsField + 19 && theme.launcherLogoTextValid(parts[wsField + 19]))
                                theme.launcherLogoText = parts[wsField + 19]
                            if (parts.length > wsField + 20 && theme.launcherLogoIconValid(parts[wsField + 20]))
                                theme.launcherLogoIcon = parts[wsField + 20]
                        } else if (lm === "omarchy" || lm === "hyprland") {
                            // Legacy cache field from the first text-logo picker.
                            theme.launcherLogoMode = "text"
                            theme.launcherLogoText = lm
                        }
                    }
                    if (parts.length > wsField + 25) theme.modPrivacy = parts[wsField + 25] !== "0"
                    if (parts.length > wsField + 26) theme.modBattery = parts[wsField + 26] !== "0"
                    if (parts.length > wsField + 27) theme.modPrivacyMic = parts[wsField + 27] !== "0"
                    else theme.modPrivacyMic = theme.modPrivacy
                    if (parts.length > wsField + 28) theme.modPrivacyCamera = parts[wsField + 28] !== "0"
                    else theme.modPrivacyCamera = theme.modPrivacy
                    if (parts.length > wsField + 29) theme.modClock = parts[wsField + 29] !== "0"
                    if (parts.length > wsField + 32) theme.modNotifications = parts[wsField + 32] !== "0"
                    if (parts.length > wsField + 33) theme.volumeManual = parts[wsField + 33] === "1"
                    if (parts.length > wsField + 34) theme.aiUsageManual = parts[wsField + 34] === "1"
                    if (parts.length > wsField + 35) theme.modTailscale = parts[wsField + 35] === "1"
                }
                theme._widgetsLoaded = true
            }
        }
    }

    Process { id: widgetSaveProc }

    // ── New widget panel states ──
    property bool networkVisible:   false
    onNetworkVisibleChanged: popupOpened("networkVisible")
    property bool bluetoothVisible: false
    onBluetoothVisibleChanged: popupOpened("bluetoothVisible")
    property bool batteryVisible:   false
    onBatteryVisibleChanged: popupOpened("batteryVisible")
    property bool mprisVisible:     false
    onMprisVisibleChanged: popupOpened("mprisVisible")
    property bool workspaceVisible: false
    onWorkspaceVisibleChanged: popupOpened("workspaceVisible")
    property bool tailscaleVisible: false
    onTailscaleVisibleChanged: {
        popupOpened("tailscaleVisible")
        if (tailscaleVisible) refreshTailscale()
    }

    // ── Image picker state (theme/wallpaper carousel) ──
    property bool   imagePickerVisible:  false
    onImagePickerVisibleChanged: popupOpened("imagePickerVisible")
    property string imagePickerMode:     "wallpaper"   // "theme" or "wallpaper"
    property real   quickActionsBarX:    0
    // ── Media browser state (screenshots/videos carousel) ──
    property bool   mediaBrowserVisible: false
    onMediaBrowserVisibleChanged: popupOpened("mediaBrowserVisible")
    property string mediaBrowserMode:    "screenshots"  // "screenshots" or "videos"
    // ── Idle state: Omarchy's native service owns lock, screensaver and DPMS. ──
    property var shellHost: null
    readonly property var idleService: shellHost ? shellHost.firstPartyServiceFor("omarchy.idle") : null
    readonly property bool idleInhibited: idleService ? idleService.stayAwake === true : false
    property int idleWidgetInstances: 0
    // ── Notification state ──
    property bool notifVisible: false
    onNotifVisibleChanged: popupOpened("notifVisible")
    property int  notifCount:   0
    property real notifBarX:    0

    // ── Power Profile state ──
    property bool powerProfileVisible: false
    onPowerProfileVisibleChanged: popupOpened("powerProfileVisible")
    property string powerProfileCurrent: ""

    Process {
        id: initPowerProfile
        command: ["bash", "-c", "powerprofilesctl get 2>/dev/null || echo balanced"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                var p = this.text.trim()
                if (p) theme.powerProfileCurrent = p
            }
        }
    }

    // ── Hyprland workspace dispatch (config-mode-aware) ──
    // Hyprland 0.55 added Lua configs but still supports classic hyprlang, and
    // BOTH ship the same version number — so the dispatch form depends on which
    // config is ACTIVE, not the version: classic wants "workspace N", Lua wants
    // hl.dsp.focus({ workspace = N }). Probe the mode once with a harmless token:
    // "hl.dsp" alone yields the Lua error "hl.dispatch: expected a dispatcher"
    // under Lua, or "Invalid dispatcher" under classic — neither switches.
    property bool hyprUsesLua: false
    Process {
        id: hyprDispatchProbe
        command: ["bash", "-c", "hyprctl dispatch 'hl.dsp' 2>&1 | grep -qi 'hl\\.dispatch' && echo lua || echo classic"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: { theme.hyprUsesLua = (this.text.trim() === "lua") }
        }
    }
    function gotoWorkspace(id) {
        if (hyprUsesLua)
            Hyprland.dispatch("hl.dsp.focus({ workspace = " + id + " })")
        else
            Hyprland.dispatch("workspace " + id)
    }

    // ── Shell Updater state (badge ⇄ panel; fed by ShellUpdateWidget's FileView) ──
    property bool shellUpdateVisible: false
    onShellUpdateVisibleChanged: popupOpened("shellUpdateVisible")
    property int  shellUpdateBehind: 0
    property var  shellUpdateSummary: []
    property string shellUpdateVersion: ""
    property real shellUpdateBarX: 0

    // ── Tray state ──
    property bool trayVisible: false
    onTrayVisibleChanged: popupOpened("trayVisible")
    property var trayPinned: []
    property real trayBarX: 10

    // ── slot-aware panel X anchors (center-X of each group; set by BarSlot) ──
    property real volumeBarX:     0
    property real networkBarX:    0
    property real batteryBarX:    0
    property real memoryBarX:     0
    property real cpuBarX:        0
    property real aiBarX:         0
    property real workspaceBarX:  0
    property real archBarX:       0
    property real bluetoothBarX:  0
    property real powerBarX:      0
    property real mprisBarX:      0
    property real launcherBarX:   6   // ControlPanel follows the Launcher/Control group
    property real tailscaleBarX:  0

    // ── Tray context-menu state (themed menu, rendered by TrayMenu.qml) ──
    property bool trayMenuVisible: false
    onTrayMenuVisibleChanged: popupOpened("trayMenuVisible")
    property var  trayMenuHandle: null   // the QsMenuHandle of the clicked item
    property real trayMenuX: 0           // global x to anchor the menu under the icon
    function openTrayMenu(handle, x) {
        trayMenuHandle = handle
        setPanelAnchor("trayMenu", x)
        trayMenuVisible = true
    }

    function trayIsHidden(item) {
        return trayPinned.indexOf(item.id) < 0
    }

    // toggle: hidden items get pinned (shown in bar); pinned items get unpinned (back to panel)
    function trayToggleHide(item) {
        var key = item.id
        if (!key) return
        var i = trayPinned.indexOf(key)
        if (i >= 0) {
            var a = trayPinned.slice(0, i)
            var b = trayPinned.slice(i + 1)
            trayPinned = a.concat(b)
            trayVisible = false
        } else {
            trayPinned = trayPinned.concat([key])
        }
    }

    Process {
        id: fontReader
        command: ["omarchy-font-current"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: theme.setMonoFont(this.text)
        }
    }

    // Bar-local entry point reached through canonical `omarchy-shell` IPC.
    // (unqualified access → resolves to the Theme root's properties; avoids the
    //  function name `theme` shadowing the `id: theme`)
    IpcHandler {
        target: "picker"
        function theme(): void       { openThemeSwitcher() }
        function wallpaper(): void   { openWallpaperSwitcher() }
        function screenshots(): void { openMediaBrowser("screenshots") }
        function videos(): void      { openMediaBrowser("videos") }
    }

}
