#!/usr/bin/env bash
set -euo pipefail

repo="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
id="io.github.sanjyay.quickshell-rise"
entry="$(jq -r '.entryPoints.bar' "$repo/manifest.json")"

jq -e --arg id "$id" '
  .schemaVersion == 1 and .id == $id and
  (.kinds | index("bar")) != null and
  (.entryPoints.bar | endswith("/Bar.qml"))
' "$repo/manifest.json" >/dev/null
[[ -f "$repo/$entry" ]]

bar="$repo/$entry"
grep -Fq 'Item {' "$bar"
! grep -Fq 'ShellRoot {' "$bar"
for property in omarchyPath shell manifest barWidgetRegistry pluginRegistry barConfig; do
  ! grep -Eq "required property [^ ]+ $property([:[:space:]]|$)" "$bar"
done
grep -Fq 'readonly property bool hostReady:' "$bar"
grep -Fq 'function tryInitialize()' "$bar"
grep -Fq 'property bool initialized: false' "$bar"
grep -Fq 'property string initializationError: ""' "$bar"
grep -Fq 'target: "quickshell-rise-health"' "$bar"
grep -Fq 'fatalError:' "$bar"
grep -Fq 'windows:' "$bar"
grep -Fq 'function debugBarGeometry()' "$bar"

! grep -Eq 'qs -c bar|qs -n -d -c bar|quickshell -c bar' \
  "$bar" "$repo/versions/rise/Bar.qml" "$repo/install.sh"
! grep -Eq 'NotificationManager|NotificationServer|HardwareOsdOverlay' \
  "$repo/versions/rise/Bar.qml"
grep -Fq 'HistoryPanel { root: theme }' "$repo/versions/rise/Bar.qml"
grep -Fq 'target: "quickshell-rise-clipboard"' "$repo/versions/rise/Bar.qml"
! grep -Eqi 'elephant|bindings\.conf|waybar|mako|swayosd|impala|iwctl' "$repo/install.sh"

smoke="$repo/tests/fixtures/smoke/Bar.qml"
[[ -f "$smoke" ]]
grep -Fq 'target: "quickshell-rise-health"' "$smoke"
grep -Fq 'function debugBarGeometry()' "$smoke"

printf 'PASS: Quattro manifest, loader, initialization, health, and ownership contracts\n'
