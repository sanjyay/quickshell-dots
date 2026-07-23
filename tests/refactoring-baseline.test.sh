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
mkdir -p "$HOME" "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME" "$XDG_STATE_HOME" "$XDG_RUNTIME_DIR" "$tmp/bin"

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
require_literal() { grep -Fq -- "$1" "$2" || fail "missing '$1' in ${2#$repo/}"; }

[[ "$(realpath -m "$HOME")" != "$(realpath -m "$real_home")" ]] || fail "temporary HOME resolves to the real HOME"
[[ "$(realpath -m "$XDG_CONFIG_HOME/quickshell/bar")" != "$(realpath -m "$real_home/.config/quickshell/bar")" ]] || fail "runtime target resolves to the real bar"
[[ "$(realpath -m "$XDG_CONFIG_HOME/hypr")" != "$(realpath -m "$real_home/.config/hypr")" ]] || fail "runtime target resolves to real Hyprland config"

for command in systemctl hyprctl qs quickshell waybar mako swayosd-server walker omarchy pkill; do
  cat > "$tmp/bin/$command" <<'SHIM'
#!/usr/bin/env bash
printf 'FAIL: forbidden live command shim invoked: %s\n' "${0##*/}" >&2
exit 97
SHIM
  chmod +x "$tmp/bin/$command"
done
export PATH="$tmp/bin:/usr/bin:/bin"

# This test only reads repository files. Never source runtime or lifecycle scripts.
ipc_expected="$tmp/ipc.expected"
cat > "$ipc_expected" <<'EOF'
layout:lock,unlock
osd:show
notifications:dismiss,dismissAll,toggleDnd,invoke,restore
health:ping
menu:open,close,toggle,ping
emoji:open,close,toggle,ping
themeSwitcher:open,close,toggle,ping
wallpaperSwitcher:open,close,toggle,ping
clipboard:open,close,ping
capture:open,close,screenshot,recording,text,color,ping
theme:apply,applyLauncher,reload,setFont
picker:theme,wallpaper,screenshots,videos
launcher:open
EOF

while IFS=: read -r target methods; do
  file="$repo/versions/default/shell.qml"
  case "$target" in theme|picker|launcher) file="$repo/versions/default/Theme.qml" ;; esac
  require_literal "target: \"$target\"" "$file"
  IFS=, read -ra method_list <<< "$methods"
  for method in "${method_list[@]}"; do
    grep -Eq "function[[:space:]]+$method[[:space:]]*\\(" "$file" || fail "missing IPC $target.$method"
  done
done < "$ipc_expected"
[[ "$(wc -l < "$ipc_expected")" -eq 13 ]] || fail "IPC target snapshot must contain 13 targets"
[[ "$(tr ':,' '\n\n' < "$ipc_expected" | tail -n +2 | wc -l)" -gt 0 ]] || fail "IPC snapshot parser failed"
method_count="$(awk -F: '{ n=split($2, methods, ","); total+=n } END { print total }' "$ipc_expected")"
[[ "$method_count" -eq 44 ]] || fail "IPC snapshot must contain 44 methods, got $method_count"

scripts_expected="$tmp/scripts.expected"
cat > "$scripts_expected" <<'EOF'
claude-usage
codex-usage
ensure-hypr-launcher-binding.sh
ensure-hypr-switcher-blur-rules.sh
opencode-usage
qs-artifact-manifest.sh
qs-capture.sh
qs-clipboard-filter.py
qs-clipboard.sh
qs-elephant-wl-paste.sh
qs-emoji.sh
qs-managed-bindings.sh
qs-menu-action.sh
qs-menu-data.sh
qs-mode.sh
qs-notification-silence.sh
qs-owned-artifacts.tsv
qs-rise-input.sh
qs-shell-apply-update.sh
qs-shell-check-update.sh
qs-shell-post-update.sh
qs-shell-refresh-local.sh
qs-state-write
qs-theme-switcher
qs-verify-config-tree.sh
qs-wallpaper-switcher
qs_usage_cache.py
swayosd-client
EOF
find "$repo/scripts" -maxdepth 1 -type f -printf '%f\n' | sort > "$tmp/scripts.actual"
diff -u "$scripts_expected" "$tmp/scripts.actual" || fail "script entrypoint snapshot changed"

units_expected="$tmp/units.expected"
cat > "$units_expected" <<'EOF'
claude-usage.service
claude-usage.timer
codex-usage.service
codex-usage.timer
elephant-clipboard-privacy.conf
opencode-usage.service
opencode-usage.timer
qs-shell-update-check.service
qs-shell-update-check.timer
EOF
find "$repo/systemd" -maxdepth 1 -type f -printf '%f\n' | sort > "$tmp/units.actual"
diff -u "$units_expected" "$tmp/units.actual" || fail "user unit/drop-in snapshot changed"

for marker in \
  '# >>> quickshell-rise managed menu bindings >>>' \
  '# <<< quickshell-rise managed menu bindings <<<' \
  '# >>> quickshell-rise managed media bindings >>>' \
  '# <<< quickshell-rise managed media bindings <<<' \
  '# >>> quickshell-rise managed notification bindings >>>' \
  '# <<< quickshell-rise managed notification bindings <<<'
do
  require_literal "$marker" "$repo/scripts/qs-managed-bindings.sh"
done
require_literal '# >>> quickshell-rise managed switcher blur rules >>>' "$repo/scripts/ensure-hypr-switcher-blur-rules.sh"
require_literal '# <<< quickshell-rise managed switcher blur rules <<<' "$repo/scripts/ensure-hypr-switcher-blur-rules.sh"
require_literal 'qs -c bar ipc call launcher open' "$repo/scripts/qs-managed-bindings.sh"
require_literal 'Toggle desktop provider' "$repo/scripts/qs-managed-bindings.sh"
require_literal 'exec "$helper" ensure-launcher' "$repo/scripts/ensure-hypr-launcher-binding.sh"

require_literal 'DEST="$HOME/.config/quickshell/bar"' "$repo/install.sh"
require_literal 'CONFIG_DIR="default"' "$repo/install.sh"
require_literal 'echo "$CONFIG_DIR" > "$stage/.qsrise"' "$repo/install.sh"
require_literal '.qsrise-source' "$repo/install.sh"
require_literal 'STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/qs-rise"' "$repo/scripts/qs-mode.sh"
require_literal 'setsid qs -n -d -c bar' "$repo/scripts/qs-mode.sh"
require_literal 'ipc call health ping' "$repo/scripts/qs-mode.sh"
require_literal 'scripts/qs-managed-bindings.sh' "$repo/scripts/qs-owned-artifacts.tsv"
require_literal 'qs_artifacts_each "$manifest" mandatory' "$repo/install.sh"
require_literal 'qs_artifacts_each "$manifest" mandatory' "$repo/scripts/qs-shell-post-update.sh"
require_literal 'qs-managed-bindings' "$repo/uninstall.sh"
require_literal 'scripts/qs_usage_cache.py' "$repo/scripts/qs-owned-artifacts.tsv"
require_literal 'optional-ai install_manifest_artifact' "$repo/install.sh"
require_literal 'optional-ai install_manifest_artifact' "$repo/scripts/qs-shell-post-update.sh"
require_literal 'qs_usage_cache.py' "$repo/uninstall.sh"
require_literal 'qs-managed-bindings" profile "$profile' "$repo/scripts/qs-shell-post-update.sh"

for root_contract in \
  'Theme {' \
  'BarSlot {' \
  'NotificationManager {' \
  'HardwareOsdOverlay {' \
  'LazyLoader {'
do
  require_literal "$root_contract" "$repo/versions/default/shell.qml"
done
require_literal 'id: theme' "$repo/versions/default/shell.qml"
require_literal 'readonly property var registry:' "$repo/versions/default/BarSlot.qml"
require_literal 'G15' "$repo/versions/default/BarSlot.qml"

for cache in quickshell_widgets quickshell_splits quickshell_barorder quickshell_barsplits; do
  rg -q -- "$cache" "$repo/versions/default" || fail "missing legacy cache contract $cache"
done
require_literal 'function saveWidgets()' "$repo/versions/default/Theme.qml"
require_literal 'function saveSplits()' "$repo/versions/default/Theme.qml"
require_literal 'function serializeOrder()' "$repo/versions/default/BarSlot.qml"
require_literal 'function serializeSplits()' "$repo/versions/default/BarSlot.qml"
require_literal 'retired package-updater fields' "$repo/versions/default/Theme.qml"
require_literal 'qs-rise-notifications.json' "$repo/versions/default/NotificationManager.qml"
require_literal 'update-available.json' "$repo/scripts/qs-shell-check-update.sh"
require_literal 'notifications-silenced' "$repo/scripts/qs-notification-silence.sh"

for orphan in IdleInhibitorWidget MediaBrowserWidget ThemeDisplayWidget MemoryWidget; do
  [[ ! -e "$repo/versions/default/modules/$orphan.qml" ]] || fail "confirmed orphan returned: $orphan.qml"
  ! rg -q --glob '*.qml' "\\b$orphan[[:space:]]*\\{" "$repo/versions/default" || fail "removed QML type is referenced: $orphan"
done
[[ ! -e "$repo/versions/default/panels/MemoryPanel.qml" ]] || fail "confirmed orphan returned: MemoryPanel.qml"
! rg -q '\bmemVisible\b' "$repo/versions/default" || fail "removed private Memory popup state returned"
! rg -q '\b(property|readonly property)[^\n]*\b(archBarX|modMedia)\b' "$repo/versions/default/Theme.qml" || fail "removed Theme property returned"

# Layout and cache compatibility placeholders are deliberately retained.
for gid in G4 G10 G13; do
  require_literal "\"$gid\"" "$repo/versions/default/BarSlot.qml"
done
require_literal 'property bool modMemory:' "$repo/versions/default/Theme.qml"
require_literal 'property bool modQuick:' "$repo/versions/default/Theme.qml"

for doc in architecture runtime-ownership ipc-compatibility providers-and-polling state-and-cache refactoring-baseline safe-validation; do
  [[ -s "$repo/docs/$doc.md" ]] || fail "missing baseline document docs/$doc.md"
done

printf 'ok (isolated refactoring baseline contract: 13 IPC targets, 44 methods)\n'
