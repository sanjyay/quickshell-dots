#!/usr/bin/env bash
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
theme="$repo/versions/default/Theme.qml"
service="$repo/versions/default/services/SystemStatusService.qml"
widget="$repo/versions/default/modules/BluetoothWidget.qml"
panel="$repo/versions/default/panels/BluetoothPanel.qml"

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
require_literal() { grep -Fq -- "$1" "$2" || fail "missing '$1' in ${2#$repo/}"; }

require_literal 'property alias bluetoothOn: systemStatus.bluetoothOn' "$theme"
require_literal 'property alias bluetoothConnectedCount: systemStatus.bluetoothConnectedCount' "$theme"
require_literal 'property bool bluetoothOn: false' "$service"
require_literal 'property int bluetoothConnectedCount: 0' "$service"
require_literal "bluetoothctl devices Connected" "$service"
require_literal 'interval: 5000' "$service"

require_literal 'readonly property bool btOn: root.bluetoothOn' "$widget"
require_literal 'readonly property int numConnected: root.bluetoothConnectedCount' "$widget"
! rg -q 'bluetoothctl|^[[:space:]]*Timer[[:space:]]*\{' "$widget" || fail "widget still owns Bluetooth polling"

# Panel-only paired-device inventory and actions remain independent.
require_literal 'bluetoothctl devices Paired' "$panel"
require_literal 'bluetoothctl connect ' "$panel"
require_literal 'bluetoothctl disconnect ' "$panel"
require_literal 'bluetoothctl power ' "$panel"

printf 'ok (singleton Bluetooth summary provider contract)\n'
