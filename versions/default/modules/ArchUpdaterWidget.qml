import QtQuick
import Quickshell
import Quickshell.Io
import "../IconMap.js" as IconMap

Item {
    id: rootMod
    required property var root

    property int updateCount: 0
    property int systemCount: 0
    property int aurCount: 0
    property bool refreshing: false
    property int retryCount: 0
    property bool parsedResult: false

    readonly property bool hasUpdates: rootMod.updateCount > 0
    readonly property int cleanThemeCount: {
        var n = 0, list = root.themeUpdList || []
        for (var i = 0; i < list.length; i++) {
            var t = list[i] || {}
            if (t.state === "clean" && t.behind > 0) n++
        }
        return n
    }
    readonly property bool hasThemeUpdates: rootMod.cleanThemeCount > 0
    readonly property bool badgePrefsLoaded: root._widgetsLoaded
    readonly property int packageBadgeCount: (rootMod.badgePrefsLoaded && root.archBadgePackages)
        ? Math.max(0, rootMod.updateCount) : 0
    readonly property int themeBadgeCount: (rootMod.badgePrefsLoaded && root.archBadgeThemes)
        ? Math.max(0, rootMod.cleanThemeCount) : 0
    readonly property int badgeCount: rootMod.packageBadgeCount + rootMod.themeBadgeCount
    readonly property bool hasBadge: rootMod.badgeCount > 0
    readonly property bool hasNotice: rootMod.hasUpdates || rootMod.hasThemeUpdates || root.themeUpdLocalEdits > 0
    // A scheduled result remains an affordance across a reload even before the
    // package list is repopulated. It is cleared only by a clean recheck.
    readonly property bool showToday: root.isArchUpdateScheduleDay
        || rootMod.hasNotice || root.archUpdateScheduleActive || root.archVisible

    visible: rootMod.showToday || implicitWidth > 0.5
    implicitWidth: rootMod.showToday ? 26 : 0
    implicitHeight: 28
    width: implicitWidth
    height: implicitHeight
    opacity: rootMod.showToday ? 1 : 0
    Behavior on implicitWidth { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
    Behavior on opacity { NumberAnimation { duration: 120 } }

    Process {
        id: checkProc
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                rootMod.parsedResult = rootMod.parseOutput(this.text)
                rootMod.refreshing = false
                refreshWatchdog.stop()
                if (!rootMod.parsedResult) rootMod.scheduleRetry()
            }
        }
        onExited: (exitCode) => {
            if (exitCode !== 0 && !rootMod.parsedResult) {
                rootMod.refreshing = false
                rootMod.scheduleRetry()
            }
            refreshWatchdog.stop()
        }
    }

    // safety: if the check ever hangs (AUR RPC stalls past the timeout), unstick
    // `refreshing` so future refreshes aren't blocked forever
    // checkupdates can sync a DB over the network + the 30s AUR timeout, so the
    // legitimate worst case is well past 45s. Kill the process (not just the flag)
    // so the state is unambiguous if it ever hangs.
    Timer {
        id: refreshWatchdog; interval: 70000
        onTriggered: { rootMod.refreshing = false; checkProc.running = false; rootMod.scheduleRetry() }
    }

    Timer {
        id: retryTimer; interval: 120000
        onTriggered: {
            if (!rootMod.refreshing && (root.archUpdateDue || root.archUpdateScheduleActive || root.archVisible))
                rootMod.doRefresh()
        }
    }

    Timer {
        // Scheduling is independent of the Status group. The provider lives in
        // the bar even while its compact badge is hidden, so a configured day
        // cannot be skipped just because tray/notification widgets are off.
        interval: 1800000; running: root.isArchUpdateScheduleDay || root.archUpdateScheduleActive || root.archVisible; repeat: true; triggeredOnStart: true
        onTriggered: root.archRefreshTick++
    }

    property int extTrigger: root.archRefreshTick
    onExtTriggerChanged: {
        if (!rootMod.refreshing && (root.archUpdateDue || root.archUpdateScheduleActive || root.archVisible)) rootMod.doRefresh()
    }

    function doRefresh() {
        rootMod.parsedResult = false
        rootMod.refreshing = true
        refreshWatchdog.restart()
        checkProc.command = [Quickshell.env("HOME") + "/.config/quickshell/bin/qs-package-update-state.sh"]
        if (root.archUpdateDue)
            checkProc.command.push("--scheduled", root.currentDateKey)
        checkProc.running = false
        checkProc.running = true
    }

    Process {
        id: notificationAckProc
        running: false
    }

    function acknowledgeNotification(key) {
        if (!key || !/^[A-Za-z0-9-]{1,128}$/.test(key)) return
        notificationAckProc.command = [Quickshell.env("HOME") + "/.config/quickshell/bin/qs-package-update-state.sh",
                                       "--ack-notification", key]
        notificationAckProc.running = false
        notificationAckProc.running = true
    }

    function parseOutput(text) {
        var lines = text.split("\n")
        var updates = []
        var sysCount = 0; var aCount = 0
        var meta = null
        for (var i = 0; i < lines.length; i++) {
            var parts = lines[i].split("|")
            if (parts[0] === "META" && parts.length >= 11) {
                meta = {
                    status: parts[1], fingerprint: parts[2], completedFingerprint: parts[3],
                    count: Number(parts[4]), system: Number(parts[5]), aur: Number(parts[6]),
                    active: parts[7] === "1", notificationKey: parts[8],
                    rebootRequired: parts[9] === "1", snapperStatus: parts[10]
                }
            } else if (parts[0] === "U" && parts.length >= 5) {
                var src = parts[1]
                if (src !== "S" && src !== "A") continue
                if (!/^[A-Za-z0-9@._+:-]+$/.test(parts[2])) continue
                if (!parts[3] || !parts[4] || parts[3].indexOf("|") >= 0 || parts[4].indexOf("|") >= 0) continue
                var entry = {name: parts[2], oldVer: parts[3], newVer: parts[4], source: src === "S" ? "system" : "aur"}
                updates.push(entry)
                if (src === "S") sysCount++
                else aCount++
            } else if (parts.length >= 4) {
                var src = parts[0]
                var entry = {name: parts[1], oldVer: parts[2], newVer: parts[3], source: src === "S" ? "system" : "aur"}
                updates.push(entry)
                if (src === "S") sysCount++
                else if (src === "A") aCount++
            }
        }
        if (!meta) return false
        if (meta.status === "failed" || meta.status === "busy") {
            // Preserve the last known package list, but surface the failed or
            // concurrent check so it cannot be mistaken for a clean completion.
            root.archUpdateStatus = meta.status
            root.archUpdateRebootRequired = meta.rebootRequired
            root.archUpdateSnapperStatus = meta.snapperStatus
            root.archUpdateScheduleActive = meta.active
            return false
        }
        rootMod.systemCount = sysCount
        rootMod.aurCount = aCount
        rootMod.updateCount = sysCount + aCount
        root.archUpdates = updates
        root.archUpdateStatus = meta.status
        root.archUpdateFingerprint = meta.fingerprint
        root.archUpdateCompletedFingerprint = meta.completedFingerprint
        root.archUpdateSettledScheduleKey = (meta.status === "clean" || meta.status === "completed") ? root.currentDateKey : ""
        root.archUpdateRebootRequired = meta.rebootRequired
        root.archUpdateSnapperStatus = meta.snapperStatus
        root.setPackageUpdateCount(rootMod.updateCount, meta.notificationKey)
        // The helper deliberately leaves a new fingerprint pending until the
        // in-process notification has been accepted. This prevents a reload or
        // startup race from permanently suppressing the first alert.
        if (meta.notificationKey) rootMod.acknowledgeNotification(meta.notificationKey)
        root.archUpdateScheduleActive = meta.active
        if (meta.status !== "failed" && meta.status !== "partial" && !root.archUpdateDue) {
            rootMod.retryCount = 0
            retryTimer.stop()
        } else {
            rootMod.scheduleRetry()
        }
        return true
    }

    function scheduleRetry() {
        if (!(root.archUpdateDue || root.archUpdateScheduleActive || root.archVisible)) return
        if (rootMod.retryCount >= 5) return
        rootMod.retryCount++
        retryTimer.restart()
    }

    Item {
        anchors.centerIn: parent
        width: 20
        height: 20

        IconText {
            id: ic
            anchors.centerIn: parent
            text: rootMod.refreshing ? "\uE5D5" : IconMap.icon("package_2")
            color: rootMod.refreshing
                ? Qt.rgba(root.sumi.r, root.sumi.g, root.sumi.b, 1)
                : (rootMod.hasNotice ? root.seal : Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.4))
            font.pixelSize: 14
        }

        Rectangle {
            visible: rootMod.hasBadge && !rootMod.refreshing
            anchors.verticalCenter: ic.verticalCenter
            anchors.verticalCenterOffset: -6
            anchors.horizontalCenter: ic.horizontalCenter
            anchors.horizontalCenterOffset: 7
            width: Math.max(12, badgeText.implicitWidth + 6)
            height: 12
            radius: 6
            color: root.seal

            Text {
                id: badgeText
                anchors.centerIn: parent
                text: rootMod.badgeCount > 99 ? "99+" : String(rootMod.badgeCount)
                color: root.paper
                font.family: root.mono
                font.pixelSize: 7
                font.weight: Font.Bold
            }
        }
    }

    readonly property string tooltipText: {
        if (rootMod.refreshing) return ""
        var parts = []
        if (rootMod.systemCount) parts.push(rootMod.systemCount + " system")
        if (rootMod.aurCount) parts.push(rootMod.aurCount + " AUR")
        if (rootMod.cleanThemeCount > 0) parts.push(rootMod.cleanThemeCount + " themes")
        if (root.themeUpdLocalEdits > 0) parts.push(root.themeUpdLocalEdits + " review")
        if (parts.length === 0) return "Up to date"
        return parts.join(" \u00B7 ") + "\nClick to view details"
    }

    TooltipMixin { id: tip; root: rootMod.root; owner: rootMod; text: rootMod.tooltipText }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onEntered: tip.show()
        onExited: tip.hide()
        onClicked: (event) => {
            tip.hide()
            if (event.button === Qt.RightButton) root.archRefreshTick++
            else root.archVisible = true
        }
    }

}
