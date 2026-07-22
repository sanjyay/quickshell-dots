import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import Quickshell.Hyprland

Scope {
    id: manager
    required property var root

    readonly property string cachePath: Quickshell.env("HOME") + "/.cache/qs-rise-notifications.json"
    property var recent: []
    property var toasts: []
    property bool cacheLoaded: false
    property string lastSaved: ""
    readonly property int unreadCount: recent.length

    function targetScreenName() {
        var focused = Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : ""
        if (focused !== "") return focused
        if (root.activePopupScreenName !== "") return root.activePopupScreenName
        for (var i = 0; i < Quickshell.screens.length; i++) {
            var screen = Quickshell.screens[i]
            if (screen.name !== "" && screen.width > 0 && screen.height > 0) return screen.name
        }
        return ""
    }

    function osdHint(notification) {
        var hints = notification.hints || ({})
        if (hints["x-quickshell-osd-kind"]) return String(hints["x-quickshell-osd-kind"])
        var summary = (notification.summary || "").trim()
        var body = (notification.body || "").trim()
        var exact = summary + (body ? " " + body : "")
        if (/^(Display mode|Monitor layout|Display profile) (changed|applied|enabled|disabled|restored)( successfully)?[.!]?$/i.test(exact))
            return "display-mode"
        return ""
    }

    function accept(notification) {
        var kind = osdHint(notification)
        if (kind !== "") {
            notification.tracked = true
            root.showHardwareOsd(kind, "", notification.body || notification.summary || "", "", targetScreenName())
            notification.dismiss()
            return
        }
        notification.tracked = true
        if (root.notifSilenced) { notification.dismiss(); return }

        var key = "notification:" + notification.id
        var entry = {
            key: key, id: notification.id, notification: notification,
            appName: notification.appName || "App", summary: notification.summary || "",
            body: notification.body || "", image: notification.image || "",
            screenName: targetScreenName(), transient: notification.transient,
            urgency: notification.urgency, expireTimeout: notification.expireTimeout
        }
        replaceOrPrepend(entry, !notification.transient)
        root.notifLatestSummary = entry.summary
        root.notifLatestBody = entry.body
        root.notifLatestApp = entry.appName
        root.notifLatestObject = notification
        root.notifSerial++
        notification.closed.connect(function() { close(key, false) })
        schedule(entry)
    }

    function replaceOrPrepend(entry, persist) {
        var nextToasts = [], replaced = false
        for (var i = 0; i < toasts.length; i++) {
            if (toasts[i].key === entry.key) { nextToasts.push(entry); replaced = true }
            else nextToasts.push(toasts[i])
        }
        if (!replaced) nextToasts.unshift(entry)
        toasts = nextToasts
        if (persist) {
            var nextRecent = [entry]
            for (var j = 0; j < recent.length; j++) if (recent[j].key !== entry.key) nextRecent.push(recent[j])
            recent = nextRecent.slice(0, 50)
            saveCache()
        }
    }

    function schedule(entry) {
        var timeout = entry.expireTimeout
        if (timeout === 0) return
        if (timeout < 0 || timeout === undefined) {
            if (entry.urgency === NotificationUrgency.Critical) return
            timeout = 5000
        }
        expiry.createObject(manager, { "entryKey": entry.key, "interval": timeout }).start()
    }

    function close(key, dismissObject) {
        var next = []
        for (var i = 0; i < toasts.length; i++) {
            if (toasts[i].key === key) {
                if (dismissObject && toasts[i].notification) toasts[i].notification.dismiss()
            } else next.push(toasts[i])
        }
        toasts = next
    }

    function dismissHistory(entry) {
        close(entry.key, true)
        var next = []
        for (var i = 0; i < recent.length; i++) if (recent[i].key !== entry.key) next.push(recent[i])
        recent = next
        saveCache()
    }

    function dismissAll() {
        for (var i = 0; i < toasts.length; i++) if (toasts[i].notification) toasts[i].notification.dismiss()
        toasts = []; recent = []; saveCache()
    }

    function invoke(entry, identifier) {
        if (!entry.notification) return
        var actions = entry.notification.actions || []
        var fallback = null
        for (var i = 0; i < actions.length; i++) {
            if (actions[i].identifier === "default") fallback = actions[i]
            if (identifier && actions[i].identifier === identifier) { actions[i].invoke(); close(entry.key, false); return }
        }
        if (fallback) fallback.invoke()
        else if (actions.length > 0) actions[0].invoke()
        close(entry.key, false)
    }

    function visibleFor(screenName) {
        var result = []
        for (var i = 0; i < toasts.length && result.length < 4; i++)
            if (toasts[i].screenName === screenName) result.push(toasts[i])
        return result
    }

    function saveCache() {
        if (!cacheLoaded) return
        var saved = []
        for (var i = 0; i < recent.length; i++) saved.push({
            key: recent[i].key, id: recent[i].id, appName: recent[i].appName,
            summary: recent[i].summary, body: recent[i].body, image: recent[i].image,
            screenName: recent[i].screenName, transient: false
        })
        var state = JSON.stringify({ recent: saved })
        if (state !== lastSaved) { lastSaved = state; cacheFile.setText(state) }
    }

    FileView {
        id: cacheFile
        path: manager.cachePath
        onLoaded: {
            try {
                var stored = JSON.parse(cacheFile.text()).recent || []
                var retained = []
                for (var i = 0; i < stored.length; i++)
                    if (stored[i].key !== "internal:package-updates") retained.push(stored[i])
                manager.recent = retained
                manager.lastSaved = cacheFile.text()
                manager.cacheLoaded = true
                if (retained.length !== stored.length) manager.saveCache()
            } catch (e) { manager.recent = [] }
            manager.cacheLoaded = true
        }
        onLoadFailed: manager.cacheLoaded = true
    }
    Component.onCompleted: cacheFile.reload()

    Component {
        id: expiry
        Timer {
            required property string entryKey
            repeat: false
            onTriggered: { manager.close(entryKey, false); destroy() }
        }
    }

    NotificationServer {
        keepOnReload: true
        persistenceSupported: false
        bodySupported: true
        bodyMarkupSupported: false
        bodyHyperlinksSupported: false
        bodyImagesSupported: true
        actionsSupported: true
        actionIconsSupported: false
        imageSupported: true
        onNotification: function(notification) { manager.accept(notification) }
    }
}
