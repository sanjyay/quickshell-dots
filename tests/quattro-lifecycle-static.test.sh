#!/usr/bin/env bash
set -euo pipefail

repo="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
install="$repo/install.sh"
uninstall="$repo/uninstall.sh"

grep -Fq 'trap rollback ERR INT TERM EXIT' "$install"
grep -Fq 'health_timeout="${QS_ASTRA_HEALTH_TIMEOUT:-15}"' "$install"
grep -Fq 'omarchy-shell shell listPlugins' "$install"
grep -Fq 'omarchy-shell shell listShellConfig' "$install"
[[ "$(grep -Fc 'omarchy-shell shell rescanPlugins' "$install")" == 3 ]]
grep -Fq 'omarchy-shell shell rescanPlugins' "$uninstall"
grep -Fq 'quickshell-astra-owned-mpv-screenrecord-action' "$install"
grep -Fq 'quickshell-astra-owned-mpv-screenrecord-action' "$uninstall"
! grep -Fq 'omarchy plugin rescan' "$install"
! grep -Fq 'omarchy plugin rescan' "$uninstall"
grep -Fq 'omarchy-shell quickshell-astra-health ping' "$install"
grep -Fq 'omarchy-shell shell debugBarGeometry' "$install"
grep -Fq 'previousBarId:' "$install"
grep -Fq 'managedLuaBlock:' "$install"
grep -Fq -- '-- BEGIN QUICKSHELL-ASTRA HISTORY BLUR' "$install"
grep -Fq 'namespace = "^quickshell-history$"' "$install"
grep -Fq 'blur = true' "$install"
grep -Fq 'ignore_alpha = 0' "$install"
grep -Fq 'filesModified: [$bindingsPath, $looknfeelPath]' "$install"
grep -Fq -- '-- BEGIN QUICKSHELL-ASTRA HISTORY BLUR' "$uninstall"
grep -Fq 'omarchy bar use "$previous_bar"' "$uninstall"
grep -Fq 'omarchy plugin remove "$PLUGIN_ID" --yes' "$uninstall"
grep -Fq 'systemd/quickshell-astra-holiday-annual-update.service' "$install"
grep -Fq 'systemctl --user enable --now "$HOLIDAY_UPDATE_UNIT.timer"' "$install"
grep -Fq '"quickshell-astra-holiday-annual-update.timer"' "$install"
grep -Fq 'quickshell-astra-holiday-annual-update' "$uninstall"
grep -Fq 'XDG_DATA_HOME' "$uninstall"

tmp="$(mktemp -d)"
trap 'rm -rf -- "$tmp"' EXIT
bindings="$tmp/bindings.lua"
cat >"$bindings" <<'LUA'
o.bind("SUPER + A", "personal", "true")
-- BEGIN QUICKSHELL-ASTRA MANAGED BLOCK
hl.unbind("SUPER + CTRL + V")
o.bind("SUPER + CTRL + V", "Quickshell Astra clipboard history", "omarchy-shell quickshell-astra-clipboard toggle")
-- END QUICKSHELL-ASTRA MANAGED BLOCK
o.bind("SUPER + B", "personal marker content", "true")
-- BEGIN QUICKSHELL-ASTRA MANAGED BLOCK
o.bind("SUPER + C", "user line inside markers", "true")
-- END QUICKSHELL-ASTRA MANAGED BLOCK
LUA

strip_block() {
  awk -v begin='-- BEGIN QUICKSHELL-ASTRA MANAGED BLOCK' -v end='-- END QUICKSHELL-ASTRA MANAGED BLOCK' '
    $0 == begin {
      begin_line=$0
      unbind_line=""; bind_line=""; end_line=""
      if ((getline unbind_line) > 0 &&
          (getline bind_line) > 0 &&
          (getline end_line) > 0 &&
          unbind_line == "hl.unbind(\"SUPER + CTRL + V\")" &&
          bind_line == "o.bind(\"SUPER + CTRL + V\", \"Quickshell Astra clipboard history\", \"omarchy-shell quickshell-astra-clipboard toggle\")" &&
          end_line == end) next
      print begin_line
      if (unbind_line != "") print unbind_line
      if (bind_line != "") print bind_line
      if (end_line != "") print end_line
      next
    }
    { print }
  ' "$1"
}

strip_block "$bindings" >"$tmp/once"
strip_block "$tmp/once" >"$tmp/twice"
cmp -s "$tmp/once" "$tmp/twice"
grep -Fq 'o.bind("SUPER + A", "personal", "true")' "$tmp/twice"
grep -Fq 'o.bind("SUPER + B", "personal marker content", "true")' "$tmp/twice"
grep -Fq 'o.bind("SUPER + C", "user line inside markers", "true")' "$tmp/twice"
[[ "$(grep -Fc -- '-- BEGIN QUICKSHELL-ASTRA MANAGED BLOCK' "$tmp/twice")" == 1 ]]
! grep -Fq 'Quickshell Astra clipboard history' "$tmp/twice"

looknfeel="$tmp/looknfeel.lua"
cat >"$looknfeel" <<'LUA'
hl.config({ general = { gaps_in = 4 } })
-- BEGIN QUICKSHELL-ASTRA HISTORY BLUR
hl.config({ decoration = { blur = { enabled = true } } })
hl.layer_rule({ match = { namespace = "^quickshell-history$" }, blur = true })
-- END QUICKSHELL-ASTRA HISTORY BLUR
LUA
awk '
  $0 == "-- BEGIN QUICKSHELL-ASTRA HISTORY BLUR" { managed=1; next }
  $0 == "-- END QUICKSHELL-ASTRA HISTORY BLUR" { managed=0; next }
  !managed { print }
' "$looknfeel" >"$tmp/looknfeel.clean"
grep -Fq 'gaps_in = 4' "$tmp/looknfeel.clean"
! grep -Fq 'QUICKSHELL-ASTRA HISTORY BLUR' "$tmp/looknfeel.clean"
lua -e "assert(loadfile('$tmp/looknfeel.clean'))"

! grep -Fq 'SUPER + SPACE' "$install"
grep -Fq 'omarchy-shell launcher open' "$repo/scripts/qs-menu-action.sh"
! grep -Fq 'AppLauncherPanel {' "$repo/versions/astra/Bar.qml"
[[ ! -e "$repo/versions/default/panels/AppLauncherPanel.qml" ]]
[[ ! -e "$repo/versions/default/helpers/app-launcher-scan.py" ]]

printf 'PASS: transactional rollback, previous-bar restore, and Lua idempotency contracts\n'
