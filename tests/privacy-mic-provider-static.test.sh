#!/usr/bin/env bash
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
theme="$repo/versions/default/Theme.qml"
service="$repo/versions/default/services/SystemStatusService.qml"
widget="$repo/versions/default/modules/PrivacyMicWidget.qml"
panel="$repo/versions/default/panels/VolumePanel.qml"

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
require_literal() { grep -Fq -- "$1" "$2" || fail "missing '$1' in ${2#$repo/}"; }

require_literal 'property alias privacyMicMuted: systemStatus.privacyMicMuted' "$theme"
require_literal 'property alias privacyMicActiveApps: systemStatus.privacyMicActiveApps' "$theme"
require_literal 'function refreshPrivacyMic()' "$theme"
require_literal 'property bool privacyMicMuted: false' "$service"
require_literal 'property int privacyMicActiveApps: 0' "$service"
require_literal 'pactl get-source-mute @DEFAULT_SOURCE@' "$service"
require_literal 'pactl list source-outputs short' "$service"
[[ "$(rg -l 'pactl get-source-mute @DEFAULT_SOURCE@' "$repo/versions/default" --glob '*.qml' | wc -l)" -eq 1 ]] || fail "microphone state read has multiple owners"

require_literal 'readonly property bool muted: root.privacyMicMuted' "$widget"
require_literal 'readonly property int activeApps: root.privacyMicActiveApps' "$widget"
require_literal 'root.togglePrivacyMic()' "$widget"
! rg -q '^[[:space:]]*(Process|Timer)[[:space:]]*\{' "$widget" || fail "privacy widget still owns polling or mutation processes"

# Preserve the panel-specific pamixer action while sharing canonical reads.
require_literal 'readonly property bool micMuted: root.privacyMicMuted' "$panel"
require_literal 'pamixer --default-source -t' "$panel"
require_literal 'onExited: root.refreshPrivacyMic()' "$panel"
! rg -q 'id: micData' "$panel" || fail "volume panel still owns duplicate microphone reads"

printf 'ok (singleton microphone privacy observation contract)\n'
