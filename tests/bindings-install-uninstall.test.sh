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

printf 'ok (bindings install/uninstall)\n'
