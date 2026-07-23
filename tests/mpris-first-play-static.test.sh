#!/usr/bin/env bash
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
selector="$repo/versions/default/modules/MprisSelect.qml"
widget="$repo/versions/default/modules/MprisWidget.qml"
theme="$repo/versions/default/Theme.qml"

require() { rg -q -- "$1" "$2" || { printf 'FAIL: missing %s in %s\n' "$1" "$2" >&2; exit 1; }; }
forbid() { ! rg -q -- "$1" "$2" || { printf 'FAIL: unexpected %s in %s\n' "$1" "$2" >&2; exit 1; }; }

# A browser may report Playing before publishing title metadata. Player
# selection must therefore be playback-driven, while the now-playing pill can
# continue waiting for a useful label.
require 'return p\.playbackState === MprisPlaybackState\.Playing' "$selector"
forbid 'playbackState === MprisPlaybackState\.Playing && hasTrack\(p\)' "$selector"
require 'readonly property bool volumeWidgetVisible: modVolume && mprisPlaying' "$theme"
require 'showNowPlaying: root\.modMpris && active && trackLabel\.length > 0' "$widget"

# Retain the existing stale-proxy and paused-player safeguards.
require 'if \(isProxy\(p\)\) return false' "$selector"
require 'if \(!hasTrack\(candidate\) \|\| isProxy\(candidate\)' "$selector"

printf 'ok (MPRIS first-play selection contract)\n'
