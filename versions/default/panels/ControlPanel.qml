import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../modules"

PanelWindow {
    id: ctrlPanel
    required property var root

    screen: root.activePopupScreen

    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "omarchy-control"
    // no mask → whole overlay is interactive (modal): click-outside + ESC work

    readonly property int barBottom: 35
    readonly property int gap: 8

    // power sub-menu starts CLOSED — no destructive tile is ever pre-shown
    property bool powerOpen: false
    property bool scheduleOpen: false
    property bool wsOpen: false   // Workspaces collapsible inside the WW fly-out
    property bool privacyOpen: false

    property real reveal: root.controlVisible ? 1 : 0
    Behavior on reveal {
        NumberAnimation {
            duration: root.controlVisible ? 160 : 120
            easing.type: root.controlVisible ? Easing.OutCubic : Easing.InCubic
        }
    }
    visible: reveal > 0.001
    onRevealChanged: if (reveal < 0.01) { powerOpen = false; scheduleOpen = false; wsOpen = false; privacyOpen = false; root.splitsSubVisible = false; root.wwSubVisible = false }  // reset when closed
    WlrLayershell.keyboardFocus: root.controlVisible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    Process {
        id: refreshProc
        command: ["bash", "-lc",
            "h=\"$HOME/.config/quickshell/bin/qs-shell-refresh-local.sh\"; " +
            "if [ -x \"$h\" ]; then setsid -f \"$h\" >/dev/null 2>&1; else exit 127; fi"]
        onExited: function(code) {
            if (code !== 0) Quickshell.reload(false)
        }
    }

    Process {
        id: qsModeProc
        command: ["bash", "-lc", "qs-mode quickshell"]
        running: false
    }

    Process {
        id: omarchyModeProc
        command: ["bash", "-lc", "qs-mode omarchy"]
        running: false
    }

    // ── reusable tile: neutral by default, highlights only on hover ──
    component Tile: Rectangle {
        property string label
        property color accent: root.seal
        property bool active: false
        signal activated()
        height: 25
        radius: root.tileRadius
        opacity: enabled ? 1.0 : 0.4          // built-in `enabled` also blocks input
        color: active ? Qt.rgba(accent.r, accent.g, accent.b, root.fillActiveAlpha) : _ma.containsMouse ? Qt.rgba(accent.r, accent.g, accent.b, root.fillHoverAlpha) : root.fillIdle
        border.color: (active || _ma.containsMouse) ? accent : root.sep
        border.width: 1
        Behavior on color { ColorAnimation { duration: 120 } }
        Text {
            anchors.centerIn: parent
            text: parent.label
            color: (parent.active || _ma.containsMouse) ? parent.accent : root.ink
            font.family: root.mono; font.pixelSize: 11
        }
        MouseArea {
            id: _ma
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: parent.activated()
        }
    }

    component ColorTile: Rectangle {
        required property var colorData
        property color swatchColor: colorData.color
        property bool active: root.barColor === colorData.id
        property bool hovered: colorMa.containsMouse
        signal activated()
        height: 25
        radius: root.tileRadius
        color: active ? Qt.rgba(swatchColor.r, swatchColor.g, swatchColor.b, root.fillActiveAlpha)
                      : hovered ? Qt.rgba(swatchColor.r, swatchColor.g, swatchColor.b, root.fillHoverAlpha)
                                : root.fillIdle
        border.color: (active || hovered) ? swatchColor : root.sep
        border.width: 1
        Behavior on color { ColorAnimation { duration: 120 } }
        UiText {
            anchors.centerIn: parent
            text: colorData.label
            color: (parent.active || parent.hovered) ? parent.swatchColor : root.ink
            font.family: root.mono
            font.pixelSize: 9
            font.weight: parent.active ? Font.Medium : Font.Normal
        }
        MouseArea {
            id: colorMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: parent.activated()
        }
    }

    MouseArea { anchors.fill: parent; onClicked: root.controlVisible = false }

    Rectangle {
        id: card
        width: 240
        height: col.implicitHeight + 24
        radius: ctrlPanel.reveal > 0.001 ? root.pillRadius : 0
        color: root.bg
        border.color: root.pillBorder
        border.width: root.pillBorderW
        PillShadow { theme: root }

        x: Math.round(Math.max(6, Math.min(root.launcherBarX - width / 2, parent.width - width - 6)))
        y: root.barPosition === "bottom" ? (parent.height - barBottom - gap - height) : (barBottom + gap)
        opacity: ctrlPanel.reveal
        focus: root.controlVisible

        Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Escape) { root.controlVisible = false; event.accepted = true }
        }

        MouseArea { anchors.fill: parent; onClicked: {} }

        Column {
            id: col
            anchors.fill: parent
            anchors.margins: 12
            spacing: 8

            // ── header ──
            Item {
                width: parent.width
                height: 24
                UiText {
                    anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                    text: "Control"
                    color: root.ink; font.family: root.mono; font.pixelSize: 13
                    font.letterSpacing: 2; font.weight: Font.Medium
                }
                UiText {
                    anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                    text: "✕"; color: closeMa.containsMouse ? root.seal : root.sumi; font.pixelSize: 12
                    Behavior on color { ColorAnimation { duration: 120 } }
                    MouseArea { id: closeMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.controlVisible = false }
                }
            }

            Rectangle { width: parent.width; height: 1; color: root.sep }

            // ── ACTIONS ──
            UiText {
                text: "ACTIONS"
                color: root.sumiHi; font.family: root.mono; font.pixelSize: 10; font.letterSpacing: 1
            }
            Tile {
                width: parent.width
                label: "Refresh QS-Config"
                onActivated: {
                    root.controlVisible = false
                    refreshProc.running = false
                    refreshProc.running = true
                }
            }
            Tile {
                width: parent.width
                label: "Quickshell UI"
                onActivated: {
                    root.controlVisible = false
                    qsModeProc.running = false
                    qsModeProc.running = true
                }
            }
            Tile {
                width: parent.width
                label: "Omarchy UI"
                onActivated: {
                    root.controlVisible = false
                    omarchyModeProc.running = false
                    omarchyModeProc.running = true
                }
            }
            Tile {
                width: parent.width
                label: ctrlPanel.scheduleOpen ? "Schedule Update  ▾" : "Schedule Update  ▸"
                active: root.archUpdateScheduleActive
                accent: root.seal
                onActivated: ctrlPanel.scheduleOpen = !ctrlPanel.scheduleOpen
            }
            Rectangle {
                width: parent.width
                height: updateInfoCol.implicitHeight + 14
                visible: root.updatesAvailable
                radius: root.tileRadius
                color: root.fillIdle
                border.color: root.sep
                border.width: 1

                Column {
                    id: updateInfoCol
                    anchors.left: parent.left
                    anchors.right: updateAction.left
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: 10
                    anchors.rightMargin: 8
                    spacing: 2
                    UiText {
                        text: "Updates"
                        color: root.ink
                        font.family: root.mono
                        font.pixelSize: 11
                        font.weight: Font.Medium
                    }
                    UiText {
                        width: parent.width
                        text: root.updateCount + (root.updateCount === 1 ? " package available" : " packages available")
                        color: root.sumi
                        font.family: root.mono
                        font.pixelSize: 10
                        elide: Text.ElideRight
                    }
                }

                Rectangle {
                    id: updateAction
                    anchors.right: parent.right
                    anchors.rightMargin: 7
                    anchors.verticalCenter: parent.verticalCenter
                    width: 58
                    height: 24
                    radius: root.tileRadius
                    color: updateActionMa.containsMouse ? root.fillPrimaryHover : root.seal
                    UiText {
                        anchors.centerIn: parent
                        text: "Update"
                        color: root.paper
                        font.family: root.mono
                        font.pixelSize: 10
                    }
                    MouseArea {
                        id: updateActionMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.activeUpdateTab = "packages"
                            root.controlVisible = false
                            root.archVisible = true
                        }
                    }
                }
            }
            Grid {
                width: parent.width
                columns: 4
                columnSpacing: 4
                rowSpacing: 4
                visible: ctrlPanel.scheduleOpen
                Repeater {
                    model: root.archUpdateDayOptions
                    delegate: Rectangle {
                        id: actionDayTile
                        required property var modelData
                        readonly property bool on: root.archUpdateDay === modelData.id
                        readonly property bool hovered: actionDayMa.containsMouse
                        width: root.evenW((col.width - 12) / 4)
                        height: 25
                        radius: root.tileRadius
                        color: on ? root.fillActive : hovered ? root.fillHover : root.fillIdle
                        border.color: (on || hovered) ? root.seal : root.sep
                        border.width: 1
                        Behavior on color { ColorAnimation { duration: 120 } }
                        UiText {
                            anchors.centerIn: parent
                            text: actionDayTile.modelData.label
                            color: (actionDayTile.on || actionDayTile.hovered) ? root.seal : root.ink
                            font.family: root.mono
                            font.pixelSize: 10
                            font.weight: actionDayTile.on ? Font.Medium : Font.Normal
                        }
                        MouseArea {
                            id: actionDayMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.archUpdateDay = actionDayTile.modelData.id
                                root.archUpdateScheduleActive = false
                            }
                        }
                    }
                }
            }

            // ── POWER (collapsed sub-menu; nothing destructive pre-shown) ──
            Tile {
                width: parent.width
                label: ctrlPanel.powerOpen ? "Power  ▾" : "Power  ▸"
                accent: root.seal
                onActivated: ctrlPanel.powerOpen = !ctrlPanel.powerOpen
            }
            Grid {
                width: parent.width
                columns: 2
                columnSpacing: 8
                rowSpacing: 8
                visible: ctrlPanel.powerOpen
                Tile {
                    width: root.evenW((col.width - 8) / 2)
                    label: "Lock"
                    onActivated: { root.controlVisible = false; Quickshell.execDetached(["hyprlock"]) }
                }
                Tile {
                    width: root.evenW((col.width - 8) / 2)
                    label: "Suspend"
                    onActivated: { root.controlVisible = false; Quickshell.execDetached(["systemctl", "suspend"]) }
                }
                Tile {
                    width: root.evenW((col.width - 8) / 2)
                    label: "Reboot"
                    accent: root.indigo
                    onActivated: { root.controlVisible = false; Quickshell.execDetached(["systemctl", "reboot"]) }
                }
                Tile {
                    width: root.evenW((col.width - 8) / 2)
                    label: "Shutdown"
                    accent: root.seal
                    onActivated: { root.controlVisible = false; Quickshell.execDetached(["systemctl", "poweroff"]) }
                }
            }

            Rectangle { width: parent.width; height: 1; color: root.sep }

            // ── BAR-COLOR: seal color source ──
            UiText {
                text: "BAR-COLOR"
                color: root.sumiHi; font.family: root.mono; font.pixelSize: 10; font.letterSpacing: 1
            }
            Grid {
                width: parent.width
                columns: 2
                columnSpacing: 8
                rowSpacing: 8
                Repeater {
                    model: root.barColorOptions
                    ColorTile {
                        required property var modelData
                        width: root.evenW((col.width - 8) / 2)
                        colorData: modelData
                        onActivated: root.barColor = modelData.id
                    }
                }
            }

            Rectangle { width: parent.width; height: 1; color: root.sep }

            // ── SPLITS (opens the fly-out sub-panel) ──
            UiText {
                text: "SPLITS"
                color: root.sumiHi; font.family: root.mono; font.pixelSize: 10; font.letterSpacing: 1
            }
            Tile {
                width: parent.width
                label: root.splitsSubVisible ? "Splits  ◂" : "Splits  ▸"
                active: root.splitsSubVisible
                accent: root.seal
                onActivated: root.splitsSubVisible = !root.splitsSubVisible
            }

            Rectangle { width: parent.width; height: 1; color: root.sep }

            // ── BAR FUNCTIONS (opens the fly-out sub-panel) ──
            UiText {
                text: "BAR FUNCTIONS"
                color: root.sumiHi; font.family: root.mono; font.pixelSize: 10; font.letterSpacing: 1
            }
            Tile {
                width: parent.width
                label: root.wwSubVisible ? "Bar Functions  ◂" : "Bar Functions  ▸"
                active: root.wwSubVisible
                onActivated: root.wwSubVisible = !root.wwSubVisible
            }

            Rectangle { width: parent.width; height: 1; color: root.sep }

        }
    }

    // ── SPLITS sub-panel (fly-out right of the ControlPanel) ──
    Rectangle {
        id: splitCard
        visible: root.controlVisible && root.splitsSubVisible
        width: 248
        height: splitCol.implicitHeight + 24
        radius: (root.controlVisible && root.splitsSubVisible) ? root.pillRadius : 0
        color: root.bg
        border.color: root.pillBorder
        border.width: root.pillBorderW
        PillShadow { theme: root }
        // open to the right of the card, or to the left if there's no room
        x: (card.x + card.width + ctrlPanel.gap + width <= parent.width - 6)
           ? card.x + card.width + ctrlPanel.gap
           : card.x - ctrlPanel.gap - width
        // bottom mode → bottom-align so a tall flyout grows UP, not into the bar
        y: root.barPosition === "bottom" ? (card.y + card.height - height) : card.y
        opacity: ctrlPanel.reveal

        MouseArea { anchors.fill: parent; onClicked: {} }

        Column {
            id: splitCol
            anchors.fill: parent
            anchors.margins: 12
            spacing: 8
            UiText {
                text: "SPLITS"
                color: root.sumiHi; font.family: root.mono; font.pixelSize: 10; font.letterSpacing: 1
            }
            Tile { width: parent.width; label: "Split all";      accent: root.seal;   onActivated: { if (root.fnSplitAll) root.fnSplitAll() } }
            Tile { width: parent.width; label: "Merge all";                            onActivated: { if (root.fnMergeAll) root.fnMergeAll() } }
            Tile { width: parent.width; label: "Default layout"; accent: root.seal;   onActivated: { if (root.fnDefaultLayout) root.fnDefaultLayout() } }

            Rectangle { width: parent.width; height: 1; color: root.sep }
            UiText {
                text: "GAP ANIM"
                color: root.sumiHi; font.family: root.mono; font.pixelSize: 10; font.letterSpacing: 1
            }
            Grid {
                id: animRow
                width: parent.width
                columns: 1
                rowSpacing: 4
                spacing: 4
                readonly property var opts: [
                    { label: "No gap animation", mode: 0 },
                    { label: "Flowing sine wave", mode: 20 },
                    { label: "Audio-reactive waveform", mode: 21 },
                    { label: "Network pulse", mode: 22 },
                    { label: "Breathing glow", mode: 23 },
                    { label: "Particle stream", mode: 24 },
                    { label: "Comet sweep", mode: 25 },
                    { label: "Electric arc", mode: 26 },
                    { label: "Gradient drift", mode: 27 },
                    { label: "Widget energy transfer", mode: 28 },
                    { label: "Idle ripple", mode: 29 },
                    { label: "Clock-synchronized wave", mode: 30 },
                    { label: "Workspace transition trail", mode: 31 },
                    { label: "Recommended combo", mode: 32 }
                ]
                Repeater {
                    model: animRow.opts
                    delegate: Rectangle {
                        id: animTile
                        required property var modelData
                        readonly property bool on:      root.barAnim === modelData.mode
                        readonly property bool hovered: animMa.containsMouse
                        width: animRow.width
                        height: 25; radius: root.tileRadius
                        color: on ? root.fillActive : hovered ? root.fillHover : root.fillIdle
                        border.color: (on || hovered) ? root.seal : root.sep
                        border.width: 1
                        Behavior on color { ColorAnimation { duration: 120 } }
                        UiText {
                            anchors.centerIn: parent
                            text: animTile.modelData.label
                            color: (animTile.on || animTile.hovered) ? root.seal : root.ink
                            font.family: root.mono; font.pixelSize: 10
                            font.weight: animTile.on ? Font.Medium : Font.Normal
                        }
                        MouseArea {
                            id: animMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.barAnim = animTile.modelData.mode
                        }
                    }
                }
            }
        }
    }

    // ── WIDGETS & WORKSPACES sub-panel (fly-out; stacks below SPLITS if both open) ──
    Rectangle {
        id: wwCard
        visible: root.controlVisible && root.wwSubVisible
        width: 248
        height: wwCol.implicitHeight + 24
        radius: (root.controlVisible && root.wwSubVisible) ? root.pillRadius : 0
        color: root.bg
        border.color: root.pillBorder
        border.width: root.pillBorderW
        PillShadow { theme: root }
        // same side as splitCard; if SPLITS is also open, stack below it
        x: (card.x + card.width + ctrlPanel.gap + width <= parent.width - 6)
           ? card.x + card.width + ctrlPanel.gap
           : card.x - ctrlPanel.gap - width
        y: (root.controlVisible && root.splitsSubVisible)
           ? (root.barPosition === "bottom" ? splitCard.y - ctrlPanel.gap - height
                                            : splitCard.y + splitCard.height + ctrlPanel.gap)
           : (root.barPosition === "bottom" ? card.y + card.height - height : card.y)
        opacity: ctrlPanel.reveal

        MouseArea { anchors.fill: parent; onClicked: {} }

        Column {
            id: wwCol
            anchors.fill: parent
            anchors.margins: 12
            spacing: 8

            // ── WIDGETS toggle grid (moved here from the main card) ──
            UiText {
                text: "WIDGETS"
                color: root.sumiHi; font.family: root.mono; font.pixelSize: 10; font.letterSpacing: 1
            }
            Grid {
                width: parent.width
                columns: 2
                columnSpacing: 8
                rowSpacing: 8
                Tile { width: root.evenW((wwCol.width - 8) / 2); label: "System info"; active: root.modCpu;       onActivated: root.modCpu = !root.modCpu }
                Tile { width: root.evenW((wwCol.width - 8) / 2); label: "Clock";       active: root.modClock;     onActivated: root.modClock = !root.modClock }
                Tile { width: root.evenW((wwCol.width - 8) / 2); label: "AI usage";    active: root.aiWidgetVisible; onActivated: root.toggleAiWidget() }
                Tile { width: root.evenW((wwCol.width - 8) / 2); label: "Power Prof."; active: root.modPower;     onActivated: root.modPower = !root.modPower }
                Tile { width: root.evenW((wwCol.width - 8) / 2); label: "Network";     active: root.modNetwork; onActivated: root.modNetwork = !root.modNetwork }
                Tile {
                    width: root.evenW((wwCol.width - 8) / 2)
                    label: root.tailscaleStatus === "unavailable" ? "Tailscale · N/A" : "Tailscale"
                    active: root.modTailscale
                    onActivated: root.modTailscale = !root.modTailscale
                }
                Tile { width: root.evenW((wwCol.width - 8) / 2); label: "Bluetooth";   active: root.modBluetooth; onActivated: root.modBluetooth = !root.modBluetooth }
                Tile { width: root.evenW((wwCol.width - 8) / 2); label: "Status";      active: root.modStatus;  onActivated: root.modStatus = !root.modStatus }
                Tile { width: root.evenW((wwCol.width - 8) / 2); label: "Notifications"; active: root.modNotifications; onActivated: root.modNotifications = !root.modNotifications }
                Tile { width: root.evenW((wwCol.width - 8) / 2); label: "Volume";      active: root.modVolume; onActivated: root.toggleVolumeWidget() }
                Tile { width: root.evenW((wwCol.width - 8) / 2); label: "Now playing"; active: root.modMpris;   onActivated: root.modMpris = !root.modMpris }
                Tile {
                    width: root.evenW((wwCol.width - 8) / 2)
                    label: ctrlPanel.privacyOpen ? "Privacy ▾" : "Privacy ▸"
                    active: root.modPrivacy && (root.modPrivacyMic || root.modPrivacyCamera)
                    onActivated: ctrlPanel.privacyOpen = !ctrlPanel.privacyOpen
                }
                Tile { width: root.evenW((wwCol.width - 8) / 2); label: "Battery";     visible: root.hasBattery; active: root.modBattery; onActivated: root.modBattery = !root.modBattery }
            }
            Grid {
                width: parent.width
                columns: 2
                columnSpacing: 8
                rowSpacing: 8
                visible: ctrlPanel.privacyOpen
                Tile {
                    width: root.evenW((wwCol.width - 8) / 2)
                    label: "Microphone"
                    active: root.modPrivacy && root.modPrivacyMic
                    onActivated: {
                        root.modPrivacyMic = !root.modPrivacyMic
                        root.modPrivacy = root.modPrivacyMic || root.modPrivacyCamera
                    }
                }
                Tile {
                    width: root.evenW((wwCol.width - 8) / 2)
                    label: "Camera"
                    active: root.modPrivacy && root.modPrivacyCamera
                    onActivated: {
                        root.modPrivacyCamera = !root.modPrivacyCamera
                        root.modPrivacy = root.modPrivacyMic || root.modPrivacyCamera
                    }
                }
            }

            // ── WORKSPACES (collapsible, like the old widgets group) ──
            Tile {
                width: parent.width
                label: ctrlPanel.wsOpen ? "Workspaces  ▾" : "Workspaces  ▸"
                onActivated: ctrlPanel.wsOpen = !ctrlPanel.wsOpen
            }
            Column {
                width: parent.width
                spacing: 8
                visible: ctrlPanel.wsOpen

                // display mode: persist 10 / persist 5 / active
                Row {
                    id: wsModeRow
                    width: parent.width
                    spacing: 4
                    readonly property var opts: [
                        { label: "Persist 10", mode: "10"     },
                        { label: "Persist 5",  mode: "5"      },
                        { label: "Active",     mode: "active" }
                    ]
                    Repeater {
                        model: wsModeRow.opts
                        delegate: Rectangle {
                            id: wsmTile
                            required property var modelData
                            readonly property bool on:      root.workspaceMode === modelData.mode
                            readonly property bool hovered: wsmMa.containsMouse
                            width: root.evenW((wsModeRow.width - wsModeRow.spacing * (wsModeRow.opts.length - 1)) / wsModeRow.opts.length)
                            height: 25; radius: root.tileRadius
                            color: on ? root.fillActive : hovered ? root.fillHover : root.fillIdle
                            border.color: (on || hovered) ? root.seal : root.sep
                            border.width: 1
                            Behavior on color { ColorAnimation { duration: 120 } }
                            UiText {
                                anchors.centerIn: parent
                                text: wsmTile.modelData.label
                                color: (wsmTile.on || wsmTile.hovered) ? root.seal : root.ink
                                font.family: root.mono; font.pixelSize: 10
                                font.weight: wsmTile.on ? Font.Medium : Font.Normal
                            }
                            MouseArea { id: wsmMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.workspaceMode = wsmTile.modelData.mode }
                        }
                    }
                }

                // display style: default / numbers / magic
                Row {
                    id: wsStyleRow
                    width: parent.width
                    spacing: 4
                    readonly property var opts: [
                        { label: "Default", mode: "default" },
                        { label: "Numbers", mode: "numbers" },
                        { label: "Magic",   mode: "magic"   }
                    ]
                    Repeater {
                        model: wsStyleRow.opts
                        delegate: Rectangle {
                            id: wssTile
                            required property var modelData
                            readonly property bool on:      root.workspaceStyle === modelData.mode
                            readonly property bool hovered: wssMa.containsMouse
                            width: root.evenW((wsStyleRow.width - wsStyleRow.spacing * (wsStyleRow.opts.length - 1)) / wsStyleRow.opts.length)
                            height: 25; radius: root.tileRadius
                            color: on ? root.fillActive : hovered ? root.fillHover : root.fillIdle
                            border.color: (on || hovered) ? root.seal : root.sep
                            border.width: 1
                            Behavior on color { ColorAnimation { duration: 120 } }
                            UiText {
                                anchors.centerIn: parent
                                text: wssTile.modelData.label
                                color: (wssTile.on || wssTile.hovered) ? root.seal : root.ink
                                font.family: root.mono; font.pixelSize: 10
                                font.weight: wssTile.on ? Font.Medium : Font.Normal
                            }
                            MouseArea { id: wssMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.workspaceStyle = wssTile.modelData.mode }
                        }
                    }
                }
            }

            Rectangle { width: parent.width; height: 1; color: root.sep }

            // ── STYLE (bar pill style; paint-only, width-invariant) ──
            UiText {
                text: "STYLE"
                color: root.sumiHi; font.family: root.mono; font.pixelSize: 10; font.letterSpacing: 1
            }
            Row {
                width: parent.width; spacing: 4
                // independent toggles: each highlights when ON, click flips it (Border+Frost+Shadow combinable)
                Tile { width: root.evenW((wwCol.width - 8) / 3); label: "Border"; active: root.styleBorder; onActivated: root.styleBorder = !root.styleBorder }
                Tile { width: root.evenW((wwCol.width - 8) / 3); label: "Frost";  active: root.styleFrost;  onActivated: root.styleFrost = !root.styleFrost }
                Tile { width: root.evenW((wwCol.width - 8) / 3); label: "Shadow"; active: root.styleShadow; onActivated: root.styleShadow = !root.styleShadow }
            }
            Row {
                width: parent.width; spacing: 4
                Tile { width: root.evenW((wwCol.width - 4) / 2); label: "Radius 12"; active: !root.styleRadiusSmall; onActivated: root.styleRadiusSmall = false }
                Tile { width: root.evenW((wwCol.width - 4) / 2); label: "Radius 6";  active: root.styleRadiusSmall;  onActivated: root.styleRadiusSmall = true }
            }

            Rectangle { width: parent.width; height: 1; color: root.sep }

            // ── POSITION (bar on top or bottom edge) ──
            UiText {
                text: "POSITION"
                color: root.sumiHi; font.family: root.mono; font.pixelSize: 10; font.letterSpacing: 1
            }
            Row {
                width: parent.width; spacing: 4
                Tile { width: root.evenW((wwCol.width - 4) / 2); label: "Top";    active: root.barPosition === "top";    onActivated: root.barPosition = "top" }
                Tile { width: root.evenW((wwCol.width - 4) / 2); label: "Bottom"; active: root.barPosition === "bottom"; onActivated: root.barPosition = "bottom" }
            }

            Rectangle { width: parent.width; height: 1; color: root.sep }

            // ── LOGO (launcher text/icon variant) ──
            UiText {
                text: "LOGO"
                color: root.sumiHi; font.family: root.mono; font.pixelSize: 10; font.letterSpacing: 1
            }
            Row {
                width: parent.width
                spacing: 4
                Tile {
                    width: root.evenW((wwCol.width - 4) / 2)
                    label: root.launcherLogoLabel(root.launcherLogoText)
                    active: root.launcherLogoMode === "text"
                    onActivated: {
                        if (root.launcherLogoMode === "text") root.nextLauncherLogoText()
                        else root.launcherLogoMode = "text"
                    }
                }
                Tile {
                    width: root.evenW((wwCol.width - 4) / 2)
                    label: root.launcherLogoLabel(root.launcherLogoIcon)
                    active: root.launcherLogoMode === "icon"
                    onActivated: {
                        if (root.launcherLogoMode === "icon") root.nextLauncherLogoIcon()
                        else root.launcherLogoMode = "icon"
                    }
                }
            }
        }
    }
}
