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
import "panels"
import "modules"

ShellRoot {
    id: root

    CameraSwitchMonitor {
        id: cameraSwitchMonitor
        Component.onCompleted: console.log("shell.qml CameraSwitchMonitor created version=" + cameraSwitchMonitor.monitorVersion)
    }

    Theme {
        id: theme
        cameraSwitch: cameraSwitchMonitor
    }

    // IPC handlers must live outside the per-monitor BarSlot delegate. Otherwise
    // multi-monitor setups register the same target once per bar.
    IpcHandler {
        target: "layout"
        function lock(): void   { theme.barUnlocked = false }
        function unlock(): void { theme.barUnlocked = true }
    }

    IpcHandler {
        target: "omarchy.system-update"
        function refresh(): void { theme.archRefreshTick++ }
    }

    IpcHandler {
        target: "osd"
        function show(kind: string, value: string, detail: string, icon: string, screen: string): void {
            theme.showHardwareOsd(kind, value, detail, icon, screen)
        }
    }

    NotificationManager { id: notificationManager; root: theme }
    Connections {
        target: theme
        function onPackageUpdatesAnnounced(count) { notificationManager.announcePackageUpdates(count) }
    }
    Connections {
        target: cameraSwitchMonitor
        function onCameraEnabledChanged() {
            if (cameraSwitchMonitor.stateKnown)
                theme.showHardwareOsd("camera", "", cameraSwitchMonitor.cameraEnabled ? "Camera enabled" : "Camera blocked", "", "")
        }
    }

    IpcHandler {
        target: "notifications"
        function dismiss(): void { if (notificationManager.toasts.length) notificationManager.close(notificationManager.toasts[0].key, true) }
        function dismissAll(): void { notificationManager.dismissAll() }
        function toggleDnd(): void { theme.notifSilenced = !theme.notifSilenced }
        function invoke(): void { if (notificationManager.toasts.length) notificationManager.invoke(notificationManager.toasts[0], "") }
        function restore(): void { theme.activateFocusedPopupScreen(); theme.notifVisible = true }
    }

    IpcHandler {
        target: "health"
        function ping(): void { }
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
        target: "emoji"
        function open(): void { theme.openEmojiPicker() }
        function close(): void { theme.emojiPickerVisible = false }
        function toggle(): void {
            if (theme.emojiPickerVisible) theme.emojiPickerVisible = false
            else theme.openEmojiPicker()
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
        target: "clipboard"
        function open(): void { theme.openClipboard() }
        function close(): void { theme.clipboardVisible = false }
        function ping(): void { }
    }

    IpcHandler {
        target: "capture"
        function open(): void { theme.captureAction = ""; theme.openCapture() }
        function close(): void { theme.captureVisible = false }
        function screenshot(): void { theme.captureAction = "screenshot"; theme.openCapture() }
        function recording(): void { theme.captureAction = "recording"; theme.openCapture() }
        function text(): void { theme.captureAction = "text"; theme.openCapture() }
        function color(): void { theme.captureAction = "color"; theme.openCapture() }
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
        console.log("shell.qml startup configPath=" + Qt.resolvedUrl("shell.qml"))
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

    Variants {
        model: root.barScreens

        delegate: Component {
            NotificationToastOverlay {
                required property var modelData
                root: theme
                manager: notificationManager
                targetScreen: modelData
            }
        }
    }

    Variants {
        model: root.barScreens
        delegate: Component {
            HardwareOsdOverlay {
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
    ClipboardHistoryPanel { root: theme }
    EmojiPickerPanel { root: theme }
    CapturePanel { root: theme }
    AppLauncherPanel { root: theme }
    CalendarPopup { root: theme }
    ArchUpdaterPanel { root: theme }
    ShellUpdatePanel { root: theme }
    PowerProfilePanel { root: theme }
    MemoryPanel { root: theme }
    CpuPanel { root: theme }
    AiUsagePanel { root: theme }
    VolumePanel { root: theme }
    TrayPanel { root: theme }
    NotificationPanel { root: theme; manager: notificationManager }
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
