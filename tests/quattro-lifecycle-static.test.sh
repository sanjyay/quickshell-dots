#!/usr/bin/env bash
set -euo pipefail

repo="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
install="$repo/install.sh"
uninstall="$repo/uninstall.sh"

grep -Fq 'trap rollback ERR INT TERM EXIT' "$install"
grep -Fq 'health_timeout="${QS_RISE_HEALTH_TIMEOUT:-15}"' "$install"
grep -Fq 'omarchy-shell shell listPlugins' "$install"
grep -Fq 'omarchy-shell shell listShellConfig' "$install"
grep -Fq 'omarchy-shell quickshell-rise-health ping' "$install"
grep -Fq 'omarchy-shell shell debugBarGeometry' "$install"
grep -Fq 'previousBarId:' "$install"
grep -Fq 'managedLuaBlock:' "$install"
grep -Fq -- '-- BEGIN QUICKSHELL-RISE HISTORY BLUR' "$install"
grep -Fq 'namespace = "^quickshell-history$"' "$install"
grep -Fq 'blur = true' "$install"
grep -Fq 'ignore_alpha = 0' "$install"
grep -Fq 'filesModified: [$bindingsPath, $looknfeelPath]' "$install"
grep -Fq -- '-- BEGIN QUICKSHELL-RISE HISTORY BLUR' "$uninstall"
grep -Fq 'omarchy bar use "$previous_bar"' "$uninstall"
grep -Fq 'omarchy plugin remove "$PLUGIN_ID" --yes' "$uninstall"

tmp="$(mktemp -d)"
trap 'rm -rf -- "$tmp"' EXIT
bindings="$tmp/bindings.lua"
cat >"$bindings" <<'LUA'
o.bind("SUPER + A", "personal", "true")
-- BEGIN QUICKSHELL-RISE MANAGED BLOCK
hl.unbind("SUPER + CTRL + V")
o.bind("SUPER + CTRL + V", "old", "false")
-- END QUICKSHELL-RISE MANAGED BLOCK
LUA

strip_block() {
  awk '
    $0 == "-- BEGIN QUICKSHELL-RISE MANAGED BLOCK" { managed=1; next }
    $0 == "-- END QUICKSHELL-RISE MANAGED BLOCK" { managed=0; next }
    !managed { print }
  ' "$1"
}

strip_block "$bindings" >"$tmp/once"
strip_block "$tmp/once" >"$tmp/twice"
cmp -s "$tmp/once" "$tmp/twice"
grep -Fq 'o.bind("SUPER + A", "personal", "true")' "$tmp/twice"
! grep -Fq 'QUICKSHELL-RISE' "$tmp/twice"

looknfeel="$tmp/looknfeel.lua"
cat >"$looknfeel" <<'LUA'
hl.config({ general = { gaps_in = 4 } })
-- BEGIN QUICKSHELL-RISE HISTORY BLUR
hl.config({ decoration = { blur = { enabled = true } } })
hl.layer_rule({ match = { namespace = "^quickshell-history$" }, blur = true })
-- END QUICKSHELL-RISE HISTORY BLUR
LUA
awk '
  $0 == "-- BEGIN QUICKSHELL-RISE HISTORY BLUR" { managed=1; next }
  $0 == "-- END QUICKSHELL-RISE HISTORY BLUR" { managed=0; next }
  !managed { print }
' "$looknfeel" >"$tmp/looknfeel.clean"
grep -Fq 'gaps_in = 4' "$tmp/looknfeel.clean"
! grep -Fq 'QUICKSHELL-RISE HISTORY BLUR' "$tmp/looknfeel.clean"
lua -e "assert(loadfile('$tmp/looknfeel.clean'))"

! grep -Fq 'SUPER + SPACE' "$install"
grep -Fq 'omarchy-shell launcher open' "$repo/scripts/qs-menu-action.sh"
! grep -Fq 'AppLauncherPanel {' "$repo/versions/rise/Bar.qml"
[[ ! -e "$repo/versions/default/panels/AppLauncherPanel.qml" ]]
[[ ! -e "$repo/versions/default/helpers/app-launcher-scan.py" ]]

printf 'PASS: transactional rollback, previous-bar restore, and Lua idempotency contracts\n'
