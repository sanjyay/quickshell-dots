#!/usr/bin/env bash
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
theme="$repo/versions/default/Theme.qml"
service="$repo/versions/default/services/SystemStatusService.qml"
widget="$repo/versions/default/modules/NotificationSilenceWidget.qml"

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
require_literal() { grep -Fq -- "$1" "$2" || fail "missing '$1' in ${2#$repo/}"; }

# Theme is the single owner of persisted DND reads, polling, and mutation.
require_literal 'property alias notifSilenced: systemStatus.notificationSilenced' "$theme"
require_literal 'function refreshNotificationSilence()' "$theme"
require_literal 'function toggleNotificationSilence()' "$theme"
require_literal 'property bool notificationSilenced: false' "$service"
require_literal 'qs-notification-silence status' "$service"
require_literal 'qs-notification-silence toggle' "$service"
require_literal 'triggeredOnStart: true' "$service"

[[ "$(rg -l 'qs-notification-silence status' "$repo/versions/default" --glob '*.qml' | wc -l)" -eq 1 ]] || fail "DND status poll has multiple owners"
[[ "$(rg -l 'qs-notification-silence toggle' "$repo/versions/default" --glob '*.qml' | wc -l)" -eq 1 ]] || fail "DND mutation has multiple owners"

# Every monitor-local indicator remains a view over the singleton state.
require_literal 'readonly property bool silenced: root.notifSilenced' "$widget"
require_literal 'root.toggleNotificationSilence()' "$widget"
! rg -q '^[[:space:]]*Process[[:space:]]*\{' "$widget" || fail "widget still owns a Process"
! rg -q '^[[:space:]]*Timer[[:space:]]*\{' "$widget" || fail "widget still owns a Timer"

# The external IPC compatibility method remains present.
require_literal 'function toggleDnd(): void' "$repo/versions/default/shell.qml"

printf 'ok (singleton notification-silence provider contract)\n'
