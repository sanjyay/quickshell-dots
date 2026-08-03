//@ pragma UseQApplication
//
// Bar lifecycle fix: bind one bar to each real Wayland output, skip
// transient nameless/0x0 placeholder screens, and recreate a BarSlot when that
// output disappears and returns. If a screen remains valid but the layer window
// loses resources or closes, recreate only that window instead of reloading the
// complete Quickshell configuration.

import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import qs.Commons
import "../default"
import "../default/panels"
import "../default/modules"

Item {
    id: root

    property string omarchyPath: ""
    property var barWidgetRegistry: null
    property var barConfig: null
    property var shell: null
    property var manifest: null
    property var pluginRegistry: null
    property bool initialized: false
    property string initializationError: ""
    property int createdWindowCount: 0
    readonly property bool idleInhibited: theme.idleInhibited
    readonly property var riseSettings: {
        var config = root.barConfig || {}
        return config.settings && typeof config.settings === "object" ? config.settings : config
    }
    readonly property var calendarHolidaySettings: {
        var calendar = riseSettings.calendar || {}
        return calendar.holidays && typeof calendar.holidays === "object" ? calendar.holidays : {}
    }

    readonly property bool hostReady: omarchyPath !== ""
        && shell !== null
        && manifest !== null
        && barConfig !== null

    function tryInitialize() {
        if (initialized || !hostReady) return
        if (typeof barConfig !== "object") {
            initializationError = "barConfig is not an object"
            return
        }
        initialized = true
    }

    function registerBarWindow() {
        createdWindowCount++
    }

    function unregisterBarWindow() {
        createdWindowCount = Math.max(0, createdWindowCount - 1)
    }

    function gpuDiagnostics() {
        var gpu = theme.systemMetrics
        return {
            collectorPath: gpu.gpuCollectorPath,
            collectorExecutable: true,
            collectorRunning: gpu.gpuCollectorRunning,
            lastExitCode: gpu.gpuLastExitCode,
            stdoutBytes: gpu.gpuStdoutBytes,
            parseStatus: gpu.gpuParseStatus,
            status: gpu.gpuStatus,
            provider: gpu.gpuProvider,
            device: gpu.gpuDevice,
            temperatureC: gpu.gpuTemperatureC,
            usagePercent: gpu.gpuUsagePercent,
            vramTotalMiB: gpu.gpuVramTotalMiB,
            clockMHz: gpu.gpuClockMHz,
            powerWatts: gpu.gpuPowerWatts,
            collectedAt: gpu.gpuCollectedAt,
            errorCode: gpu.gpuErrorCode,
            displayModelReady: gpu.gpuDisplayModelReady
        }
    }

    function idleDiagnostics() {
        var nativeIdle = theme.idleService
        return {
            backend: "omarchy-native",
            requested: theme.idleInhibited,
            effective: nativeIdle ? nativeIdle.stayAwake === true && nativeIdle.idleEnabled === false : false,
            serviceReady: nativeIdle !== null,
            observerInstances: theme.idleWidgetInstances
        }
    }

    function refreshAiUsage() {
        return theme.forceAiUsageRefresh(false)
    }

    function aiUsageDiagnostics() {
        return theme.aiUsageDiagnosticObject()
    }

    function networkDiagnostics() {
        var net = theme.network
        return {
            serviceInstances: 1,
            installed: net.installed,
            connected: net.connected,
            connectionType: net.connectionType,
            interfaceName: net.interfaceName,
            connectionSpeedMbps: net.connectionSpeedMbps,
            connectivity: net.connectivity,
            pingMs: net.pingMs,
            packetLossPercent: net.packetLossPercent,
            receiveRateBytes: net.receiveRateBytes,
            transmitRateBytes: net.transmitRateBytes,
            nearbyNetworkCount: net.nearbyNetworks.length,
            dnsMode: net.dnsMode,
            speedTestAvailable: net.speedTestAvailable,
            scanning: net.scanning,
            lastRefreshAt: net.lastRefreshAt,
            lastSuccessfulRefreshAt: net.lastSuccessfulRefreshAt,
            lastErrorCode: net.lastErrorCode || null
        }
    }

    function refreshNetwork() {
        theme.network.refresh(true)
        return true
    }

    function openAiUsage(provider) {
        if (provider === "codex" || provider === "claude" || provider === "opencode")
            theme.aiTool = provider
        theme.activateFocusedPopupScreen()
        theme.aiUsageVisible = true
    }

    function closeAiUsage() {
        theme.aiUsageVisible = false
    }

    function openSystemMetrics() {
        theme.activateFocusedPopupScreen()
        theme.cpuVisible = true
    }

    function closeSystemMetrics() {
        theme.cpuVisible = false
    }

    function openCalendar() {
        theme.openCalendar()
    }

    function showCalendarMonth(year, month) {
        if (year < 1900 || year > 2200 || month < 1 || month > 12) return false
        var now = new Date()
        theme.openCalendar()
        theme.calendarMonthOffset = (year - now.getFullYear()) * 12
            + (month - 1 - now.getMonth())
        theme.selectedDay = 1
        theme.selectedCalendarDate = theme.localIsoDate(year, month - 1, 1)
        theme.calendarTick++
        return true
    }

    function closeCalendar() {
        theme.calendarVisible = false
    }

    function holidayDiagnostics() {
        var service = theme.holidays
        var records = []
        var regional = []
        var bankClosures = []
        var dates = Object.keys(service.holidaysByDate).sort()
        for (var i = 0; i < dates.length; i++) {
            var rows = service.holidaysByDate[dates[i]] || []
            for (var j = 0; j < rows.length; j++) {
                records.push(rows[j])
                if (rows[j].scope === "regional") regional.push(rows[j])
                if (rows[j].type === "bank-closure") bankClosures.push(rows[j])
            }
        }
        return {
            status: service.status,
            stateLoaded: service.stateLoaded,
            migrationPending: service.migrationPending,
            countryMode: service.countrySelectionMode,
            detectedCountry: service.detectedCountryCode,
            effectiveCountry: service.effectiveCountryCode,
            configuredSubdivision: service.configuredSubdivisionCode,
            effectiveSubdivision: service.effectiveSubdivisionCode,
            showNational: service.showNational,
            showRegional: service.showRegional,
            displayedYear: service.displayedYear,
            providerId: service.activeProviderId,
            providerKind: service.activeProviderKind,
            providerSource: service.activeProviderSource,
            holidayDates: dates,
            records: records,
            regional: regional,
            bankClosures: bankClosures
        }
    }

    function historyDiagnostics() {
        return theme.historyDiagnosticsProvider ? theme.historyDiagnosticsProvider.diagnosticsObject() : {}
    }

    function capabilityDiagnostics() {
        return theme.runtimeCapabilities ? theme.runtimeCapabilities.diagnosticsObject() : {
            probed: false, probeCount: 0, capabilities: {}
        }
    }

    function debugBarGeometry() {
        var geometry = []
        for (var i = 0; i < barScreens.length; i++) {
            var screen = barScreens[i]
            geometry.push({
                id: "quickshell-astra",
                screen: screen.name,
                x: 0,
                y: 0,
                width: screen.width,
                height: theme.barReservedExtent,
                visible: initialized
            })
        }
        return geometry
    }

    onOmarchyPathChanged: tryInitialize()
    onShellChanged: tryInitialize()
    onManifestChanged: tryInitialize()
    onBarConfigChanged: tryInitialize()

    CameraSwitchMonitor {
        id: cameraSwitchMonitor
        Component.onCompleted: console.log("shell.qml CameraSwitchMonitor created version=" + cameraSwitchMonitor.monitorVersion)
    }

    Theme {
        id: theme
        cameraSwitch: cameraSwitchMonitor
        aiCollectorReady: root.initialized
        systemMetricsReady: root.initialized
        networkServiceReady: root.initialized
        shellHost: root.shell
        calendarHolidayConfig: root.calendarHolidaySettings
    }

    // IPC handlers must live outside the per-monitor BarSlot delegate. Otherwise
    // multi-monitor setups register the same target once per bar.
    IpcHandler {
        target: "layout"
        function lock(): void   { theme.barUnlocked = false }
        function unlock(): void { theme.barUnlocked = true }
    }

    IpcHandler {
        target: "menu"
        function open(route: string): void { theme.openMenu(route || "root") }
        function close(): void { theme.menuVisible = false }
        function toggle(): void {
            if (theme.menuVisible) theme.menuVisible = false
            else theme.openMenu("root")
        }
        function ping(): void { }
    }

    IpcHandler {
        target: "themeSwitcher"
        function open(): void { theme.openThemeSwitcher() }
        function close(): void { theme.themeSwitcherVisible = false }
        function toggle(): void {
            if (theme.themeSwitcherVisible) theme.themeSwitcherVisible = false
            else theme.openThemeSwitcher()
        }
        function ping(): void { }
    }

    IpcHandler {
        target: "wallpaperSwitcher"
        function open(): void { theme.openWallpaperSwitcher() }
        function close(): void { theme.wallpaperSwitcherVisible = false }
        function toggle(): void {
            if (theme.wallpaperSwitcherVisible) theme.wallpaperSwitcherVisible = false
            else theme.openWallpaperSwitcher()
        }
        function ping(): void { }
    }

    IpcHandler {
        target: "quickshell-astra-clipboard"
        function open(): void { theme.openClipboard() }
        function close(): void { theme.clipboardVisible = false }
        function toggle(): void {
            if (theme.clipboardVisible) theme.clipboardVisible = false
            else theme.openClipboard()
        }
        function state(): string { return theme.clipboardVisible ? "open" : "closed" }
        function diagnostics(): string { return JSON.stringify(root.historyDiagnostics()) }
        function ping(): void { }
    }

    // Deprecated Rise alias sharing the canonical Astra clipboard panel.
    IpcHandler {
        target: "quickshell-rise-clipboard"
        function open(): void { theme.openClipboard() }
        function close(): void { theme.clipboardVisible = false }
        function toggle(): void {
            if (theme.clipboardVisible) theme.clipboardVisible = false
            else theme.openClipboard()
        }
        function state(): string { return theme.clipboardVisible ? "open" : "closed" }
        function diagnostics(): string { return JSON.stringify(root.historyDiagnostics()) }
        function ping(): void { }
    }

    // QtWayland creates a nameless 0x0 placeholder screen while no real output
    // exists; exclude it so no unusable layer surface is created. A new real
    // ShellScreen identity makes Variants destroy the old BarSlot and
    // instantiate a fresh one.
    readonly property var barScreens: {
        var valid = []

        for (var i = 0; i < Quickshell.screens.length; i++) {
            var candidate = Quickshell.screens[i]
            if (candidate.name !== "" && candidate.width > 0 && candidate.height > 0) {
                valid.push(candidate)
            }
        }

        return valid
    }

    function activeScreenStillValid() {
        if (!theme.activePopupScreenName) return false

        for (var i = 0; i < barScreens.length; i++) {
            if (barScreens[i].name === theme.activePopupScreenName) return true
        }

        return false
    }

    function ensureActivePopupScreen() {
        if (barScreens.length === 0) {
            theme.closePopups()
            theme.activePopupScreen = null
            theme.activePopupScreenName = ""
        } else if (!activeScreenStillValid()) {
            if (theme.anyPopupVisible) theme.closePopups()
            theme.activatePopupScreen(barScreens[0])
        }
    }

    onBarScreensChanged: ensureActivePopupScreen()
    Component.onCompleted: {
        tryInitialize()
        ensureActivePopupScreen()
    }

    // Secondary guard for failures that do not replace the ShellScreen object.
    // resourcesLost is followed by closed, so one pending flag handles the pair
    // once. A closed PanelWindow drops its backing layer-shell window; setting
    // visible=true creates a fresh one without resetting the rest of the shell.
    component BarWindowRecovery: Scope {
        id: recovery

        required property var targetWindow
        required property var targetScreen

        property bool pending: false
        property int attempt: 0
        property string reason: ""

        function screenReady() {
            return targetScreen !== null
                && targetScreen.name !== ""
                && targetScreen.width > 0
                && targetScreen.height > 0
        }

        function schedule(reason_) {
            if (pending) return

            pending = true
            attempt = 0
            reason = reason_
            console.warn("[BarWindowRecovery] window lost: " + reason)
            retryTimer.restart()
        }

        Connections {
            target: recovery.targetWindow

            function onResourcesLost() { recovery.schedule("resourcesLost") }
            function onClosed() { recovery.schedule("closed") }
        }

        Timer {
            id: retryTimer
            interval: 750
            repeat: false
            onTriggered: {
                // Screen replacement is owned by Variants. The delegate and this
                // timer will normally be destroyed before reaching this branch.
                if (!recovery.screenReady()) {
                    console.warn("[BarWindowRecovery] invalid screen; waiting for Variants")
                    recovery.pending = false
                    return
                }

                recovery.attempt++
                console.warn("[BarWindowRecovery] recreating bar window (attempt "
                             + recovery.attempt + "/3)")
                recovery.targetWindow.visible = true
                verifyTimer.restart()
            }
        }

        Timer {
            id: verifyTimer
            interval: 1200
            repeat: false
            onTriggered: {
                if (recovery.targetWindow.backingWindowVisible) {
                    console.log("[BarWindowRecovery] bar window recovered")
                    recovery.pending = false
                    recovery.attempt = 0
                } else if (recovery.attempt < 3 && recovery.screenReady()) {
                    retryTimer.restart()
                } else {
                    console.warn("[BarWindowRecovery] targeted recovery failed")
                    recovery.pending = false
                }
            }
        }
    }

    component PopupDismissLayer: PanelWindow {
        id: dismissLayer

        required property var root
        required property var targetScreen

        screen: targetScreen
        color: Qt.rgba(0, 0, 0, 0.001)
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.focusable: dismissLayer.visible
        WlrLayershell.keyboardFocus: dismissLayer.visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        WlrLayershell.namespace: "quickshell-popup-dismiss"
        mask: Region { item: hitArea }

        Rectangle {
            id: hitArea
            x: 0
            y: 0
            width: dismissLayer.width
            height: dismissLayer.height
            color: Qt.rgba(0, 0, 0, 0.001)

            MouseArea {
                anchors.fill: parent
                enabled: dismissLayer.visible
                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                onPressed: function(event) {
                    if (dismissLayer.root.pointerTrace)
                        dismissLayer.root.tracePointer(hitArea, "popup-dismiss-layer", event, "pressed")
                }
                onClicked: function(event) {
                    if (dismissLayer.root.pointerTrace)
                        dismissLayer.root.tracePointer(hitArea, "popup-dismiss-layer", event, "clicked")
                    dismissLayer.root.closePopups()
                }
            }
        }
        visible: root.anyPopupVisible
            && !root.keyboardPopupVisible
            && targetScreen
            && targetScreen.name !== ""
            && !root.isActivePopupScreenName(targetScreen.name)
    }

    Variants {
        model: root.barScreens

        delegate: Component {
            BarSlot {
                id: barWindow
                required property var modelData

                root: theme
                screen: modelData
                Component.onCompleted: registerBarWindow()
                Component.onDestruction: unregisterBarWindow()

                BarWindowRecovery {
                    targetWindow: barWindow
                    targetScreen: barWindow.modelData
                }
            }
        }
    }

    Variants {
        model: root.barScreens

        delegate: Component {
            PopupDismissLayer {
                required property var modelData

                root: theme
                targetScreen: modelData
            }
        }
    }

    TooltipOverlay { root: theme }
    OmarchyMenuPanel { root: theme }
    ThemeSwitcherPanel { root: theme }
    WallpaperSwitcherPanel { root: theme }
    HistoryPanel { root: theme }
    CalendarPopup { root: theme }
    ShellUpdatePanel { root: theme }
    PowerProfilePanel { root: theme }
    MemoryPanel { root: theme }
    CpuPanel { root: theme }
    AiUsagePanel { root: theme }
    VolumePanel { root: theme }
    TrayPanel { root: theme }
    NetworkPanel { root: theme }
    BluetoothPanel { root: theme }
    TailscalePanel { root: theme }
    BatteryPanel { root: theme }
    MprisPanel { root: theme }
    WorkspacePanel { root: theme }
    ControlPanel { root: theme }
    TrayMenu { root: theme }

    // Picker variants: only the selected pickerStyle is instantiated.
    LazyLoader { active: theme.pickerStyle === "tanzaku" || theme.pickerStyle === "";  ImageCarouselPanel       { root: theme } }
    LazyLoader { active: theme.pickerStyle === "hearthstone";                           ImageCarouselHearthstone { root: theme } }
    LazyLoader { active: theme.pickerStyle === "carousel";                              ImageCarouselCarousel    { root: theme } }
    LazyLoader { active: theme.pickerStyle === "tanzaku" || theme.pickerStyle === "";  MediaBrowserPanel        { root: theme } }
    LazyLoader { active: theme.pickerStyle === "hearthstone";                           MediaBrowserHearthstone  { root: theme } }
    LazyLoader { active: theme.pickerStyle === "carousel";                              MediaBrowserCarousel     { root: theme } }
}
