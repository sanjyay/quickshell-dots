#!/usr/bin/env bash
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
service="$repo/versions/default/services/NetworkSummaryService.qml"
widget="$repo/versions/default/modules/NetworkWidget.qml"
panel="$repo/versions/default/panels/NetworkPanel.qml"
theme="$repo/versions/default/Theme.qml"
astra="$repo/versions/astra/Bar.qml"

require() {
  rg -q -- "$1" "$2" || {
    printf 'FAIL: missing %s in %s\n' "$1" "$2" >&2
    exit 1
  }
}

require_fixed() {
  rg -Fq -- "$1" "$2" || {
    printf 'FAIL: missing %s in %s\n' "$1" "$2" >&2
    exit 1
  }
}

require 'import Quickshell.Networking' "$service"
require 'NetworkSummaryService' "$theme"
require 'readonly property var network: networkService' "$theme"
require 'readonly property var network: root.network' "$widget"
require 'network.connectedSsid \|\| "Wi-Fi"' "$panel"
require 'root.networkVisible = !root.networkVisible' "$widget"
require 'network.toggleNetwork' "$widget"
require 'network.refresh' "$widget"
require 'SPEED TEST' "$panel"
require 'DNS PROVIDER' "$panel"
require 'OTHER NETWORKS' "$panel"
require 'connectWithPsk' "$service"
require 'stdinEnabled: true' "$service"
require 'property var fallbackWifiRows' "$service"
require 'property bool speedExpectedStop' "$service"
require 'service.finishSpeedPhase' "$service"
require_fixed 'dnsAction.command = ["omarchy-dns", provider]' "$service"
require 'omarchy-launch-floating-terminal-with-presentation' "$service"
require 'typeof entry.network.connect === "function"' "$service"
require '"nmcli", "--ask", "--wait", "15"' "$service"
require 'serviceInstances: 1' "$astra"

if rg -q 'iwctl|impala|qs -c bar|quickshell -c bar' "$service" "$widget" "$panel"; then
  echo "FAIL: legacy or standalone network path found" >&2
  exit 1
fi

if rg -q 'on(Connected|WifiEnabled|Active)Changed:.*(toggle|=)' "$service" "$widget" "$panel"; then
  echo "FAIL: reactive backend writeback found" >&2
  exit 1
fi

echo "PASS: shared Quattro NetworkManager service and panel contracts"
