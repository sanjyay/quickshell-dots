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

[[ "$(realpath -m "$HOME")" != "$(realpath -m "$real_home")" ]] || fail "temporary HOME resolves to real HOME"

for command in systemctl hyprctl qs quickshell waybar mako swayosd-server walker omarchy pkill powerprofilesctl; do
  cat > "$tmp/bin/$command" <<'SHIM'
#!/usr/bin/env bash
printf 'FAIL: forbidden live command shim invoked: %s\n' "${0##*/}" >&2
exit 97
SHIM
  chmod +x "$tmp/bin/$command"
done
export PATH="$tmp/bin:/usr/bin:/bin"

theme="$repo/versions/default/Theme.qml"
service="$repo/versions/default/services/SystemStatusService.qml"
widget="$repo/versions/default/modules/PowerProfileWidget.qml"
panel="$repo/versions/default/panels/PowerProfilePanel.qml"

# Theme is the singleton owner of reads, polling, mutation, and optimistic state.
require_literal 'property alias powerProfileCurrent: systemStatus.powerProfileCurrent' "$theme"
require_literal 'function refreshPowerProfile()' "$theme"
require_literal 'function setPowerProfile(profile)' "$theme"
require_literal 'property string powerProfileCurrent: ""' "$service"
require_literal 'powerprofilesctl get 2>/dev/null || echo balanced' "$service"
require_literal 'property Process powerProfileReadProc' "$service"
require_literal 'running: true' "$service"
require_literal 'interval: 5000' "$service"
require_literal 'running: service.powerProfileEnabled || service.powerProfileVisible' "$service"
require_literal 'triggeredOnStart: true' "$service"
require_literal 'powerprofilesctl set ' "$service"
require_literal 'powerProfileCurrent = profile' "$service"

[[ "$(rg -l 'powerprofilesctl get' "$repo/versions/default" --glob '*.qml' | wc -l)" -eq 1 ]] || fail "power profile read has multiple owners"
[[ "$(rg -l 'powerprofilesctl set' "$repo/versions/default" --glob '*.qml' | wc -l)" -eq 1 ]] || fail "power profile mutation has multiple owners"

# Views preserve their feature-specific behavior and delegate only the command.
require_literal 'property string profile: root.powerProfileCurrent' "$widget"
require_literal 'root.setPowerProfile(next)' "$widget"
require_literal 'root.powerProfileVisible = !root.powerProfileVisible' "$widget"
require_literal 'root.setPowerProfile(modelData.key)' "$panel"
require_literal 'root.powerProfileVisible = false' "$panel"

! rg -q '^[[:space:]]*Process[[:space:]]*\{' "$widget" || fail "widget still owns a Process"
! rg -q '^[[:space:]]*Timer[[:space:]]*\{' "$widget" || fail "widget still owns a Timer"
! rg -q '^[[:space:]]*Process[[:space:]]*\{' "$panel" || fail "panel still owns a Process"

printf 'ok (isolated singleton power-profile provider contract)\n'
