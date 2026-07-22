#!/usr/bin/env bash
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
require_line() {
  local needle="$1" file="$2"
  grep -Fqx -- "$needle" "$file" || fail "missing '$needle' in $file"
}
forbid_line() {
  local needle="$1" file="$2"
  ! grep -Fqx -- "$needle" "$file" || fail "unexpected '$needle' in $file"
}

launcher_bind_file="$tmp/home1/.config/hypr/bindings.conf"
mkdir -p "$(dirname "$launcher_bind_file")"
printf '%s\n' 'user = kept' > "$launcher_bind_file"
HOME="$tmp/home1" bash "$repo/scripts/ensure-hypr-launcher-binding.sh" >/dev/null
require_line 'unbind = SUPER, SPACE' "$launcher_bind_file"
require_line 'bind = SUPER, SPACE, exec, qs -c bar ipc call launcher open' "$launcher_bind_file"
require_line 'unbind = SUPER SHIFT, SPACE' "$launcher_bind_file"
require_line "bindd = SUPER SHIFT, SPACE, Toggle desktop provider, exec, bash -lc 'if [[ \"\$(qs-mode status)\" == quickshell ]]; then qs-mode omarchy; else qs-mode quickshell; fi'" "$launcher_bind_file"
require_line 'user = kept' "$launcher_bind_file"
HOME="$tmp/home1" bash "$repo/uninstall.sh" >/dev/null
require_line 'user = kept' "$launcher_bind_file"
forbid_line 'bind = SUPER, SPACE, exec, qs -c bar ipc call launcher open' "$launcher_bind_file"
forbid_line 'bindd = SUPER SHIFT, SPACE, Toggle desktop provider, exec, bash -lc '\''if [[ "$(qs-mode status)" == quickshell ]]; then qs-mode omarchy; else qs-mode quickshell; fi'\''' "$launcher_bind_file"

launcher_created_file="$tmp/home2/.config/hypr/bindings.conf"
mkdir -p "$(dirname "$launcher_created_file")"
HOME="$tmp/home2" bash "$repo/scripts/ensure-hypr-launcher-binding.sh" >/dev/null
require_line 'bind = SUPER, SPACE, exec, qs -c bar ipc call launcher open' "$launcher_created_file"
HOME="$tmp/home2" bash "$repo/uninstall.sh" >/dev/null
[[ ! -e "$launcher_created_file" ]] || fail "expected $launcher_created_file to be removed"

looknfeel_file="$tmp/home3/.config/hypr/looknfeel.conf"
mkdir -p "$(dirname "$looknfeel_file")"
printf '%s\n' 'decoration { rounding = 8 }' > "$looknfeel_file"
HOME="$tmp/home3" bash "$repo/scripts/ensure-hypr-switcher-blur-rules.sh" >/dev/null
require_line 'decoration { rounding = 8 }' "$looknfeel_file"
require_line '# >>> quickshell-rise managed switcher blur rules >>>' "$looknfeel_file"
require_line 'layerrule = blur on, match:namespace quickshell-theme-switcher' "$looknfeel_file"
require_line 'layerrule = ignore_alpha 0, match:namespace quickshell-theme-switcher' "$looknfeel_file"
require_line 'layerrule = blur on, match:namespace quickshell-wallpaper-switcher' "$looknfeel_file"
require_line 'layerrule = ignore_alpha 0, match:namespace quickshell-wallpaper-switcher' "$looknfeel_file"
HOME="$tmp/home3" bash "$repo/scripts/ensure-hypr-switcher-blur-rules.sh" >/dev/null
[[ "$(grep -Fc '# >>> quickshell-rise managed switcher blur rules >>>' "$looknfeel_file")" == 1 ]] || fail "switcher blur block duplicated"
HOME="$tmp/home3" bash "$repo/uninstall.sh" >/dev/null
require_line 'decoration { rounding = 8 }' "$looknfeel_file"
forbid_line 'layerrule = blur on, match:namespace quickshell-theme-switcher' "$looknfeel_file"

printf 'ok (bindings install/uninstall)\n'
