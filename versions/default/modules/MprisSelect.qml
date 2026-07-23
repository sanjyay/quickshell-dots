import QtQuick
import Quickshell
import Quickshell.Services.Mpris

// Single source of truth for "which player is active".
// The bar widget and the panel both instantiate this, so they can never
// disagree about the current player.
//
// playerctld can leave a ghost entry that reports Playing after the real
// player has exited. Treat that proxy as "no player".
QtObject {
    id: sel

    // Only players paused through the bar are eligible when nothing is
    // currently playing.  This keeps ordinary stale MPRIS entries hidden.
    property var pausedPlayers: []

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
        // Browsers can publish Playing before the first track metadata update.
        // Select the live player immediately so playback-driven widgets appear;
        // metadata consumers will update independently when the title arrives.
        return p.playbackState === MprisPlaybackState.Playing
    }

    function hasTrack(p) {
        return !!(p && p.trackTitle && p.trackTitle.length > 0)
    }

    readonly property var player: {
        var vals = Mpris.players.values
        for (var i = 0; i < vals.length; i++) {
            var p = vals[i]
            if (!isReal(p)) continue
            return p
        }

        // Prefer the most recently paused player that still exists.  A new
        // player can temporarily take precedence while it is playing; once it
        // closes, the older bar-paused track becomes available again.
        var remembered = pausedPlayers || []
        for (var r = remembered.length - 1; r >= 0; r--) {
            var candidate = remembered[r]
            if (!hasTrack(candidate) || isProxy(candidate)
                    || candidate.playbackState === MprisPlaybackState.Playing) continue
            for (var j = 0; j < vals.length; j++) {
                if (vals[j] === candidate) return candidate
            }
        }
        return null
    }

    readonly property bool active:  player !== null
    readonly property bool playing: player !== null && player.playbackState === MprisPlaybackState.Playing
}
