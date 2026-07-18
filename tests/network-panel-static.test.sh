#!/usr/bin/env bash
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
panel="$repo/versions/default/panels/NetworkPanel.qml"
require() { rg -q -- "$1" "$panel" || { printf 'FAIL: missing %s\n' "$1" >&2; exit 1; }; }

require 'property var    savedNetworks:'
require 'property string wifiTab: "available"'
require 'label: "Available"'
require 'label: "Saved"'
require 'netPanel.wifiTab = modelData.id'
require 'SAVED NETWORKS'
require 'netPanel.wifiTab === "available" \? netPanel.networks : netPanel.savedNetworks'
require 'No saved networks'
require 'iwctl known-networks list'
require 'netPanel.savedNetworks = saved'
require 'onClicked: netPanel.scan\(\)'
require 'onClicked: netPanel.toggleWifi\(\)'
require 'Network settings'
require 'property bool speedDetailsVisible: false'
require 'id: speedDetailsContainer'
require 'height: netPanel.speedDetailsVisible \? speedDetails.implicitHeight : 0'
require 'netPanel.speedDetailsVisible = true'
require 'netPanel.speedDetailsVisible = false'
echo 'ok (network panel available/saved tabs)'
