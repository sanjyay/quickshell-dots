#!/usr/bin/env bash
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
theme="$repo/versions/default/Theme.qml"
service="$repo/versions/default/services/SystemStatusService.qml"
widget="$repo/versions/default/modules/VoxtypeWidget.qml"

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
require_literal() { grep -Fq -- "$1" "$2" || fail "missing '$1' in ${2#$repo/}"; }

require_literal 'property alias voxState: systemStatus.voxtypeState' "$theme"
require_literal 'property alias voxHint: systemStatus.voxtypeHint' "$theme"
require_literal 'property alias hasVoxtype: systemStatus.hasVoxtype' "$theme"
require_literal 'timeout 1 voxtype status --extended --format json' "$service"
require_literal 'if (parts[0] === "MISSING")' "$service"
require_literal 'service.hasVoxtype = false' "$service"
require_literal 'running: service.hasVoxtype' "$service"
[[ "$(rg -l 'voxtype status --extended' "$repo/versions/default" --glob '*.qml' | wc -l)" -eq 1 ]] || fail "Voxtype status has multiple owners"

require_literal 'readonly property string state: root.voxState' "$widget"
require_literal 'readonly property string hint: root.voxHint' "$widget"
require_literal 'omarchy-voxtype-model' "$widget"
require_literal 'omarchy-voxtype-config' "$widget"
[[ "$(rg -o '^[[:space:]]*Process[[:space:]]*\{' "$widget" | wc -l)" -eq 2 ]] || fail "widget should retain only its two action processes"
! rg -q '^[[:space:]]*Timer[[:space:]]*\{' "$widget" || fail "widget still owns status polling"

printf 'ok (singleton optional Voxtype provider contract)\n'
