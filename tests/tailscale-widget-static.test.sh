#!/usr/bin/env bash
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
theme="$repo/versions/default/Theme.qml"
bar="$repo/versions/default/BarSlot.qml"
panel="$repo/versions/default/panels/ControlPanel.qml"
widget="$repo/versions/default/modules/TailscaleWidget.qml"
info_panel="$repo/versions/default/panels/TailscalePanel.qml"
shell="$repo/versions/default/shell.qml"

require() { rg -q -- "$1" "$2" || { printf 'FAIL: missing %s in %s\n' "$1" "$2" >&2; exit 1; }; }
forbid() {
    local pattern="$1" file
    shift
    for file in "$@"; do
        ! rg -q -- "$pattern" "$file" || { printf 'FAIL: unexpected %s in %s\n' "$pattern" "$file" >&2; exit 1; }
    done
}

require 'property bool modTailscale:[[:space:]]+false' "$theme"
require 'tailscale status --json' "$theme"
require 'running: theme.modTailscale' "$theme"
require '\+ \(modTailscale \? "1" : "0"\).*\+35' "$theme"
require 'wsField \+ 35.*modTailscale' "$theme"
require 'label: root.tailscaleStatus === "unavailable" \? "Tailscale · N/A" : "Tailscale"' "$panel"
require 'onActivated: root.modTailscale = !root.modTailscale' "$panel"
require 'id: compTailscale' "$bar"
require '"G15": compTailscale' "$bar"
require 'ListElement \{ gid: "G15" \}' "$bar"
require 'r.length === rightModel.count - 1' "$bar"
require 'r.push\("G15"\)' "$bar"
require 'implicitWidth: shown \? row.implicitWidth \+ 16 : 0' "$widget"
require 'readonly property bool shown: root.modTailscale' "$widget"
require 'acceptedButtons: Qt.LeftButton \| Qt.RightButton' "$widget"
require '\["tailscale", "down"\]' "$widget"
require '\["tailscale", "up"\]' "$widget"
require 'mouse.button === Qt.RightButton' "$widget"
require 'tailscaleVisible = !rootMod.root.tailscaleVisible' "$widget"
require 'rootMod.root.refreshTailscale\(\)' "$widget"
forbid 'TooltipMixin|tooltipText|onEntered:|onExited:[[:space:]]+tip\.' "$widget"
require 'modules/TailscaleWidget.qml' "$repo/install.sh"
require 'panels/TailscalePanel.qml' "$repo/install.sh"
require 'TailscalePanel \{ root: theme \}' "$shell"
require 'Qt.Key_Escape' "$info_panel"
require 'Peers online' "$info_panel"
forbid 'tailscale (up|down|login|logout|switch|set)' "$theme" "$bar" "$panel" "$repo/install.sh" "$repo/uninstall.sh"

printf 'ok (Tailscale widget configuration contract)\n'
