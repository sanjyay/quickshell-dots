#!/usr/bin/env bash
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
real_home="${HOME:?HOME must be set}"
tmp="$(mktemp -d)"
trap 'rm -rf -- "$tmp"' EXIT

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
require_line() { grep -Fqx -- "$1" "$bindings" || fail "missing '$1'"; }
forbid_line() { ! grep -Fqx -- "$1" "$bindings" || fail "unexpected '$1'"; }
require_count() {
  local expected="$1" needle="$2" actual
  actual="$(grep -Fxc -- "$needle" "$bindings" || true)"
  [[ "$actual" -eq "$expected" ]] || fail "expected $expected copies of '$needle', got $actual"
}

export HOME="$tmp/home"
export XDG_CONFIG_HOME="$HOME/.config"
export HYPR_BINDINGS_CONF="$XDG_CONFIG_HOME/hypr/bindings.conf"
bindings="$HYPR_BINDINGS_CONF"
helper="$repo/scripts/qs-managed-bindings.sh"
mkdir -p "$(dirname "$bindings")"

[[ "$(realpath -m "$HOME")" != "$(realpath -m "$real_home")" ]] || fail "temporary HOME resolves to real HOME"
[[ "$(realpath -m "$bindings")" != "$(realpath -m "$real_home/.config/hypr/bindings.conf")" ]] || fail "binding target resolves to real configuration"

printf '%s\n' \
  'user-before = kept' \
  'bindd = SUPER SHIFT, SPACE, Refresh Quickshell bar, exec, bash -lc '\''qs -c bar kill; sleep 0.2; qs -n -d -c bar'\''' \
  'user-after = kept' > "$bindings"

bash "$helper" ensure-launcher
require_line 'user-before = kept'
require_line 'user-after = kept'
require_line 'unbind = SUPER, SPACE'
require_line 'bind = SUPER, SPACE, exec, qs -c bar ipc call launcher open'
require_line 'unbind = SUPER SHIFT, SPACE'
require_line "bindd = SUPER SHIFT, SPACE, Toggle desktop provider, exec, bash -lc 'if [[ \"\$(qs-mode status)\" == quickshell ]]; then qs-mode omarchy; else qs-mode quickshell; fi'"
forbid_line 'bindd = SUPER SHIFT, SPACE, Refresh Quickshell bar, exec, bash -lc '\''qs -c bar kill; sleep 0.2; qs -n -d -c bar'\'''
bash "$helper" ensure-launcher
require_count 1 'unbind = SUPER, SPACE'
require_count 1 'bind = SUPER, SPACE, exec, qs -c bar ipc call launcher open'

bash "$helper" profile quickshell
require_count 1 '# >>> quickshell-rise managed menu bindings >>>'
require_count 1 '# >>> quickshell-rise managed media bindings >>>'
require_count 1 '# >>> quickshell-rise managed notification bindings >>>'
require_line 'bind = SUPER, SPACE, exec, qs -c bar ipc call -- launcher open'
forbid_line 'bind = SUPER, SPACE, exec, qs -c bar ipc call launcher open'
require_count 1 'unbind = SUPER, SPACE'
require_count 1 "bindd = SUPER SHIFT, SPACE, Toggle desktop provider, exec, bash -lc 'if [[ \"\$(qs-mode status)\" == quickshell ]]; then qs-mode omarchy; else qs-mode quickshell; fi'"
require_line 'bindeld = , XF86AudioRaiseVolume, Quickshell volume up, exec, qs-rise-input volume up'
bash "$helper" profile quickshell
require_count 1 '# >>> quickshell-rise managed menu bindings >>>'
require_count 1 '# >>> quickshell-rise managed media bindings >>>'
require_count 1 '# >>> quickshell-rise managed notification bindings >>>'

bash "$helper" profile omarchy
require_count 1 '# >>> quickshell-rise managed menu bindings >>>'
require_count 0 '# >>> quickshell-rise managed media bindings >>>'
require_count 0 '# >>> quickshell-rise managed notification bindings >>>'
require_line 'bindd = SUPER, SPACE, Launch apps, exec, omarchy-launch-walker'
forbid_line 'bind = SUPER, SPACE, exec, qs -c bar ipc call launcher open'
require_count 1 'unbind = SUPER, SPACE'
require_count 1 "bindd = SUPER SHIFT, SPACE, Toggle desktop provider, exec, bash -lc 'if [[ \"\$(qs-mode status)\" == quickshell ]]; then qs-mode omarchy; else qs-mode quickshell; fi'"

bash "$helper" remove
require_line 'user-before = kept'
require_line 'user-after = kept'
require_count 0 '# >>> quickshell-rise managed menu bindings >>>'
forbid_line 'unbind = SUPER, SPACE'
forbid_line 'bind = SUPER, SPACE, exec, qs -c bar ipc call launcher open'

if compgen -G "$(dirname "$bindings")/.qs-rise-bindings.*" >/dev/null; then
  fail "atomic binding edit left a temporary file"
fi

printf 'ok (isolated authoritative managed-binding transformer)\n'
