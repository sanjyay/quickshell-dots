#!/usr/bin/env bash
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
real_home="${HOME:?HOME must be set}"
tmp="$(mktemp -d)"
trap 'rm -rf -- "$tmp"' EXIT

export HOME="$tmp/home"
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_CACHE_HOME="$HOME/.cache"
export XDG_STATE_HOME="$HOME/.local/state"
export XDG_RUNTIME_DIR="$tmp/runtime"
export QS_SHELL_SOURCE="$repo"
export QS_SHELL_DEST="$HOME/.config/quickshell/bar"
mkdir -p "$QS_SHELL_DEST" "$XDG_STATE_HOME" "$XDG_RUNTIME_DIR" "$tmp/bin"

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
[[ "$(realpath -m "$HOME")" != "$(realpath -m "$real_home")" ]] || fail "temporary HOME resolves to real HOME"
[[ "$QS_SHELL_DEST" == "$tmp"/* ]] || fail "destination escaped fixture"

printf 'default\n' > "$QS_SHELL_DEST/.qsrise"
printf '%s\n' "$repo" > "$QS_SHELL_DEST/.qsrise-source"
printf 'fixture quote\n' > "$QS_SHELL_DEST/quotes.txt"
printf 'stale\n' > "$QS_SHELL_DEST/stale.qml"

for command in systemctl hyprctl qs quickshell waybar mako swayosd-server walker omarchy; do
  cat > "$tmp/bin/$command" <<'SHIM'
#!/usr/bin/env bash
printf '%s %s\n' "${0##*/}" "$*" >> "$QS_TEST_COMMAND_LOG"
exit 0
SHIM
  chmod +x "$tmp/bin/$command"
done
for command in pkill pgrep setsid notify-send; do
  cat > "$tmp/bin/$command" <<'SHIM'
#!/usr/bin/env bash
printf '%s %s\n' "${0##*/}" "$*" >> "$QS_TEST_COMMAND_LOG"
[[ "${0##*/}" == pgrep ]] && exit 1
exit 0
SHIM
  chmod +x "$tmp/bin/$command"
done
export QS_TEST_COMMAND_LOG="$tmp/commands.log"
: > "$QS_TEST_COMMAND_LOG"
export PATH="$tmp/bin:/usr/bin:/bin"

bash "$repo/scripts/qs-shell-refresh-local.sh"

[[ "$(cat "$QS_SHELL_DEST/quotes.txt")" == "fixture quote" ]] || fail "custom quotes were not preserved"
[[ ! -e "$QS_SHELL_DEST/stale.qml" ]] || fail "stale runtime file survived refresh"
[[ "$(cat "$QS_SHELL_DEST/.qsrise")" == default ]] || fail "ownership marker changed"
[[ "$(cat "$QS_SHELL_DEST/.qsrise-source")" == "$repo" ]] || fail "source marker changed"
bash "$repo/scripts/qs-verify-config-tree.sh" "$repo/versions/default" "$QS_SHELL_DEST"
cmp -s "$repo/scripts/qs-state-write" "$HOME/.local/bin/qs-state-write" || fail "state writer was not synchronized"
cmp -s "$repo/scripts/qs-managed-bindings.sh" "$HOME/.local/bin/qs-managed-bindings" || fail "binding helper was not synchronized"
grep -Fq 'setsid qs -n -d -c bar' "$QS_TEST_COMMAND_LOG" || fail "bar relaunch was not requested through shim"

printf 'ok (isolated local refresh and companion parity)\n'
