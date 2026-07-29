#!/usr/bin/env bash
set -euo pipefail

repo="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
plugin_id="io.github.sanjyay.quickshell-rise"

jq -e --arg id "$plugin_id" \
  '.schemaVersion == 1 and .id == $id and .kinds == ["bar"] and .entryPoints.bar == "versions/default/Bar.qml"' \
  "$repo/manifest.json" >/dev/null
grep -Fq 'property string omarchyPath:' "$repo/versions/default/Bar.qml"
grep -Fq 'property var barWidgetRegistry:' "$repo/versions/default/Bar.qml"
grep -Fq 'property var barConfig:' "$repo/versions/default/Bar.qml"
! grep -Fq 'ShellRoot {' "$repo/versions/default/Bar.qml"
! grep -Fq 'NotificationManager {' "$repo/versions/default/Bar.qml"
! grep -Fq 'HardwareOsdOverlay {' "$repo/versions/default/Bar.qml"
grep -Fq 'import qs.Commons' "$repo/versions/default/Theme.qml"
grep -Fq 'Color.bar.background' "$repo/versions/default/Theme.qml"
grep -Fq 'omarchy bar use "$PLUGIN_ID"' "$repo/install.sh"
grep -Fq 'omarchy-shell shell ping' "$repo/install.sh"
! grep -Eq 'qs -(n |c )|quickshell -c bar|elephant service enable' "$repo/install.sh"

printf 'PASS: Quattro plugin contract and lifecycle\n'
