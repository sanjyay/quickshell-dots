#!/usr/bin/env bash
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
theme="$repo/versions/default/Theme.qml"
service="$repo/versions/default/services/NetworkSummaryService.qml"
widget="$repo/versions/default/modules/NetworkWidget.qml"
panel="$repo/versions/default/panels/NetworkPanel.qml"

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
require_literal() { grep -Fq -- "$1" "$2" || fail "missing '$1' in ${2#$repo/}"; }

for alias in networkMode networkSsid networkSignal networkIface networkDlRate networkUlRate networkDlHistory networkUlHistory useNM; do
  require_literal "property alias $alias:" "$theme"
done
require_literal 'ip route get 1.1.1.1' "$service"
require_literal '/proc/net/dev' "$service"
require_literal 'iw dev' "$service"
require_literal 'readonly property bool fastPoll: enabled || panelVisible || mode === "wifi"' "$service"
require_literal 'interval: service.fastPoll ? 2000 : 60000' "$service"
require_literal 'if (downloads.length > maxSamples) downloads.shift()' "$service"
require_literal 'systemctl is-active --quiet NetworkManager' "$service"
require_literal 'service.useNetworkManager = this.text.trim() === "1"' "$service"
! rg -q 'command: .*systemctl is-active --quiet NetworkManager' "$theme" || fail "Theme still owns network backend probing"

require_literal 'readonly property string mode: root.networkMode' "$widget"
require_literal 'readonly property var dlHistory: root.networkDlHistory' "$widget"
! rg -q 'ip route get|/proc/net/dev|^[[:space:]]*Timer[[:space:]]*\{' "$widget" || fail "widget still owns network polling"

# Scanning, saved-network parsing, detail and actions remain panel-specific.
require_literal 'iwctl station' "$panel"
require_literal 'property var    networks: []' "$panel"
require_literal 'property var    savedNetworks: []' "$panel"
require_literal 'id: netData' "$panel"

printf 'ok (singleton network-summary provider contract)\n'
