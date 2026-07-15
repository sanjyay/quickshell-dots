import QtQuick
import Quickshell
import Quickshell.Services.Mpris

// Single source of truth for "which player is active".
// The bar widget and the panel both instantiate this, so they can never
// disagree about the current player.
//
// playerctld (and dead apps) can leave ghost entries that report Playing
// after the real player has exited. Treat those as "no player".
QtObject {
    id: sel

    // playerctld is an aggregator proxy: it mirrors the last player and
    // freezes its state (often "Playing") once that player quits, leaving a
    // ghost entry. Real players always appear under their own bus name too,
    // so skip the proxy entirely and let the real entry win.
    function isProxy(p) {
        var n = (p.dbusName || "") + " " + (p.identity || "")
        return /playerctld/i.test(n)
    }

    function isReal(p) {
        if (!p) return false
        if (isProxy(p)) return false
        // A paused player is not active media. In particular, browsers and
        // playerctld commonly retain paused metadata across a reboot, which
        // made the now-playing pill appear with nothing actually playing.
        return p.playbackState === MprisPlaybackState.Playing
            && !!(p.trackTitle && p.trackTitle.length > 0)
    }

    readonly property var player: {
        var vals = Mpris.players.values
        for (var i = 0; i < vals.length; i++) {
            var p = vals[i]
            if (!isReal(p)) continue
            return p
        }
        return null
    }

    readonly property bool active:  player !== null
    readonly property bool playing: player !== null && player.playbackState === MprisPlaybackState.Playing
}
