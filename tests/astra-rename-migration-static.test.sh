#!/usr/bin/env bash
set -euo pipefail

repo="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
install="$repo/install.sh"
uninstall="$repo/uninstall.sh"

jq -e '.id == "io.github.sanjyay.quickshell-astra" and .name == "Quickshell Astra" and .entryPoints.bar == "runtime/Bar.qml"' \
  "$repo/manifest.json" >/dev/null
[[ -f "$repo/versions/astra/Bar.qml" ]]
[[ ! -e "$repo/versions/rise" ]]
grep -Fq 'import "../versions/astra" as AstraComponents' "$repo/runtime/Bar.qml"
grep -Fq 'target: "quickshell-astra-health"' "$repo/runtime/Bar.qml"
grep -Fq 'target: "quickshell-astra-clipboard"' "$repo/versions/astra/Bar.qml"
grep -Fq 'target: "quickshell-rise-health"' "$repo/runtime/Bar.qml"
grep -Fq 'target: "quickshell-rise-clipboard"' "$repo/versions/astra/Bar.qml"

for contract in \
  'LEGACY_STATE_FILE="$LEGACY_STATE_HOME/install-state.json"' \
  'LEGACY_PLUGIN_ID="io.github.sanjyay.quickshell-rise"' \
  'LEGACY_BLOCK_BEGIN="-- BEGIN QUICKSHELL-RISE MANAGED BLOCK"' \
  'LEGACY_HOLIDAY_UPDATE_UNIT="quickshell-rise-holiday-annual-update"'; do
  grep -Fq "$contract" "$install"
done
grep -Fq 'LEGACY_STATE_FILE="$LEGACY_STATE_HOME/install-state.json"' "$uninstall"
grep -Fq 'leaving unrecognized legacy plugin path untouched' "$uninstall"
! grep -Fq 'rm -rf -- "$LEGACY_STATE_HOME"' "$install"
! grep -Fq 'rm -rf -- "$LEGACY_STATE_HOME"' "$uninstall"

tmp="$(mktemp -d)"
trap 'rm -rf -- "$tmp"' EXIT
bindings="$tmp/bindings.lua"
cat >"$bindings" <<'LUA'
o.bind("SUPER + R", "user rise project", "true")
-- BEGIN QUICKSHELL-RISE MANAGED BLOCK
hl.unbind("SUPER + CTRL + V")
o.bind("SUPER + CTRL + V", "Quickshell Rise clipboard history", "omarchy-shell quickshell-rise-clipboard toggle")
-- END QUICKSHELL-RISE MANAGED BLOCK
LUA
awk -v begin='-- BEGIN QUICKSHELL-ASTRA MANAGED BLOCK' \
    -v end='-- END QUICKSHELL-ASTRA MANAGED BLOCK' \
    -v legacy_begin='-- BEGIN QUICKSHELL-RISE MANAGED BLOCK' \
    -v legacy_end='-- END QUICKSHELL-RISE MANAGED BLOCK' '
  $0 == begin || $0 == legacy_begin { managed=1; next }
  $0 == end || $0 == legacy_end { managed=0; next }
  !managed { print }
' "$bindings" >"$tmp/clean"
grep -Fq 'user rise project' "$tmp/clean"
! grep -Fq 'quickshell-rise-clipboard' "$tmp/clean"

printf 'PASS: Astra rename, Rise migration, aliases, and unrelated-rise preservation contracts\n'
