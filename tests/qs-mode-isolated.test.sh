#!/usr/bin/env bash
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
real_home="${HOME:?HOME must be set}"
tmp="$(mktemp -d)"
trap 'rm -rf -- "$tmp"' EXIT

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
require_line() { grep -Fqx -- "$1" "$2" || fail "missing '$1' in $2"; }
forbid_line() { ! grep -Fqx -- "$1" "$2" || fail "unexpected '$1' in $2"; }
require_count() {
  local expected="$1" needle="$2" file="$3" actual
  actual="$(grep -Fxc -- "$needle" "$file" || true)"
  [[ "$actual" -eq "$expected" ]] || fail "expected $expected copies of '$needle' in $file, got $actual"
}

export HOME="$tmp/home"
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_CACHE_HOME="$HOME/.cache"
export XDG_STATE_HOME="$HOME/.local/state"
export XDG_RUNTIME_DIR="$tmp/runtime"
export HYPR_BINDINGS_CONF="$XDG_CONFIG_HOME/hypr/bindings.conf"
export QS_TEST_COMMAND_LOG="$tmp/commands.log"
export QS_TEST_HEALTH=success
export QS_MANAGED_BINDINGS_HELPER="$repo/scripts/qs-managed-bindings.sh"
mkdir -p "$HOME/.config/quickshell/bar" "$(dirname "$HYPR_BINDINGS_CONF")" "$XDG_STATE_HOME/qs-rise" "$XDG_RUNTIME_DIR" "$tmp/bin"
printf '// isolated shell fixture\n' > "$HOME/.config/quickshell/bar/shell.qml"
printf '%s\n' 'user = preserved' > "$HYPR_BINDINGS_CONF"
printf 'omarchy\n' > "$XDG_STATE_HOME/qs-rise/mode"

[[ "$(realpath -m "$HOME")" != "$(realpath -m "$real_home")" ]] || fail "temporary HOME resolves to real HOME"
[[ "$(realpath -m "$HYPR_BINDINGS_CONF")" != "$(realpath -m "$real_home/.config/hypr/bindings.conf")" ]] || fail "binding target resolves to real configuration"

cat > "$tmp/bin/qs" <<'SHIM'
#!/usr/bin/env bash
printf 'qs\t%s\n' "$*" >> "${QS_TEST_COMMAND_LOG:?}"
case "$*" in
  'list -c bar -j') printf '[]\n' ;;
  'list --all')
    [[ "${QS_TEST_HEALTH:-fail}" == success ]] && printf '%s\n' "$HOME/.config/quickshell/bar/shell.qml"
    ;;
  *'ipc call health ping') [[ "${QS_TEST_HEALTH:-fail}" == success ]] ;;
esac
SHIM
chmod +x "$tmp/bin/qs"

for command in systemctl pkill setsid omarchy waybar mako swayosd-server walker hyprctl; do
  cat > "$tmp/bin/$command" <<'SHIM'
#!/usr/bin/env bash
printf '%s\t%s\n' "${0##*/}" "$*" >> "${QS_TEST_COMMAND_LOG:?}"
case "${0##*/}" in
  pkill) exit 1 ;;
  *) exit 0 ;;
esac
SHIM
  chmod +x "$tmp/bin/$command"
done
cat > "$tmp/bin/sleep" <<'SHIM'
#!/usr/bin/env bash
exit 0
SHIM
chmod +x "$tmp/bin/sleep"
export PATH="$tmp/bin:/usr/bin:/bin"

# Match installation order: seed launcher/toggle compatibility lines before the
# profile state machine normalizes the active profile block.
bash "$repo/scripts/qs-managed-bindings.sh" ensure-launcher

mode_file="$XDG_STATE_HOME/qs-rise/mode"
menu_begin='# >>> quickshell-rise managed menu bindings >>>'
menu_end='# <<< quickshell-rise managed menu bindings <<<'
media_begin='# >>> quickshell-rise managed media bindings >>>'
media_end='# <<< quickshell-rise managed media bindings <<<'
notif_begin='# >>> quickshell-rise managed notification bindings >>>'
notif_end='# <<< quickshell-rise managed notification bindings <<<'

# Successful Quickshell activation is health-gated and idempotent.
bash "$repo/scripts/qs-mode.sh" quickshell >/dev/null
[[ "$(cat "$mode_file")" == quickshell ]] || fail "successful health check did not persist quickshell"
require_line 'user = preserved' "$HYPR_BINDINGS_CONF"
require_count 1 "$menu_begin" "$HYPR_BINDINGS_CONF"
require_count 1 "$menu_end" "$HYPR_BINDINGS_CONF"
require_count 1 "$media_begin" "$HYPR_BINDINGS_CONF"
require_count 1 "$media_end" "$HYPR_BINDINGS_CONF"
require_count 1 "$notif_begin" "$HYPR_BINDINGS_CONF"
require_count 1 "$notif_end" "$HYPR_BINDINGS_CONF"
require_line 'bind = SUPER, SPACE, exec, qs -c bar ipc call -- launcher open' "$HYPR_BINDINGS_CONF"
forbid_line 'bind = SUPER, SPACE, exec, qs -c bar ipc call launcher open' "$HYPR_BINDINGS_CONF"
require_count 1 'unbind = SUPER, SPACE' "$HYPR_BINDINGS_CONF"
require_line 'bindd = SUPER, COMMA, Dismiss notification, exec, qs -c bar ipc call -- notifications dismiss' "$HYPR_BINDINGS_CONF"
bash "$repo/scripts/qs-mode.sh" quickshell >/dev/null
require_count 1 "$menu_begin" "$HYPR_BINDINGS_CONF"
require_count 1 "$media_begin" "$HYPR_BINDINGS_CONF"
require_count 1 "$notif_begin" "$HYPR_BINDINGS_CONF"

# Omarchy restores its menu commands and removes Quickshell-only blocks.
bash "$repo/scripts/qs-mode.sh" omarchy >/dev/null
[[ "$(cat "$mode_file")" == omarchy ]] || fail "Omarchy transition did not persist omarchy"
require_count 1 "$menu_begin" "$HYPR_BINDINGS_CONF"
require_count 1 "$menu_end" "$HYPR_BINDINGS_CONF"
require_count 0 "$media_begin" "$HYPR_BINDINGS_CONF"
require_count 0 "$notif_begin" "$HYPR_BINDINGS_CONF"
require_line 'bindd = SUPER, SPACE, Launch apps, exec, omarchy-launch-walker' "$HYPR_BINDINGS_CONF"
forbid_line 'bind = SUPER, SPACE, exec, qs -c bar ipc call -- launcher open' "$HYPR_BINDINGS_CONF"
require_line 'user = preserved' "$HYPR_BINDINGS_CONF"
bash "$repo/scripts/qs-mode.sh" omarchy >/dev/null
require_count 1 "$menu_begin" "$HYPR_BINDINGS_CONF"

# A failed Quickshell health check restores the safe Omarchy provider stack and
# must never record an unhealthy Quickshell mode.
export QS_TEST_HEALTH=fail
if bash "$repo/scripts/qs-mode.sh" quickshell >/dev/null 2>&1; then
  fail "unhealthy Quickshell transition unexpectedly succeeded"
fi
[[ "$(cat "$mode_file")" == omarchy ]] || fail "failed health check did not restore Omarchy state"
if compgen -G "$XDG_STATE_HOME/qs-rise/.mode.*" >/dev/null; then
  fail "atomic mode write left a temporary file"
fi
require_count 1 "$menu_begin" "$HYPR_BINDINGS_CONF"
require_count 0 "$media_begin" "$HYPR_BINDINGS_CONF"
require_count 0 "$notif_begin" "$HYPR_BINDINGS_CONF"
require_line 'bindd = SUPER, SPACE, Launch apps, exec, omarchy-launch-walker' "$HYPR_BINDINGS_CONF"

grep -q '^systemctl[[:space:]]' "$QS_TEST_COMMAND_LOG" || fail "systemctl was not intercepted"
grep -q '^hyprctl[[:space:]]reload$' "$QS_TEST_COMMAND_LOG" || fail "Hyprland reload was not intercepted"
grep -q '^qs[[:space:]].*ipc call health ping' "$QS_TEST_COMMAND_LOG" || fail "health ping was not exercised"

printf 'ok (isolated qs-mode switching, idempotency, and rollback)\n'
