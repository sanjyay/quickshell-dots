#!/usr/bin/env bash
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
theme="$repo/versions/default/Theme.qml"
service="$repo/versions/default/services/SystemStatusService.qml"
widget="$repo/versions/default/modules/IdleWidget.qml"

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
require_literal() { grep -Fq -- "$1" "$2" || fail "missing '$1' in ${2#$repo/}"; }

require_literal 'property alias idleAwake: systemStatus.idleAwake' "$theme"
require_literal 'function refreshIdleState()' "$theme"
require_literal 'function toggleIdleState()' "$theme"
require_literal 'property bool idleAwake: false' "$service"
require_literal 'pgrep -x hypridle' "$service"
require_literal 'omarchy-toggle-idle' "$service"

[[ "$(rg -l 'pgrep -x hypridle' "$repo/versions/default" --glob '*.qml' | wc -l)" -eq 1 ]] || fail "Hypridle observation has multiple owners"
[[ "$(rg -l 'omarchy-toggle-idle' "$repo/versions/default" --glob '*.qml' | wc -l)" -eq 1 ]] || fail "Hypridle mutation has multiple owners"

require_literal 'readonly property bool awake: root.idleAwake' "$widget"
require_literal 'root.toggleIdleState()' "$widget"
! rg -q '^[[:space:]]*Process[[:space:]]*\{' "$widget" || fail "widget still owns a Process"
! rg -q '^[[:space:]]*Timer[[:space:]]*\{' "$widget" || fail "widget still owns a Timer"

printf 'ok (singleton Hypridle observation contract)\n'
