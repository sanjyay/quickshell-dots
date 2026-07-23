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
require_regex() { rg -q -- "$1" "$2" || fail "missing /$1/ in ${2#$repo/}"; }

[[ "$(realpath -m "$HOME")" != "$(realpath -m "$real_home")" ]] || fail "temporary HOME resolves to real HOME"
[[ "$(realpath -m "$XDG_CONFIG_HOME/quickshell/bar")" != "$(realpath -m "$real_home/.config/quickshell/bar")" ]] || fail "test resolves to live bar"

for command in systemctl hyprctl qs quickshell waybar mako swayosd-server walker omarchy pkill; do
  cat > "$tmp/bin/$command" <<'SHIM'
#!/usr/bin/env bash
printf 'FAIL: forbidden live command shim invoked: %s\n' "${0##*/}" >&2
exit 97
SHIM
  chmod +x "$tmp/bin/$command"
done
export PATH="$tmp/bin:/usr/bin:/bin"

theme="$repo/versions/default/Theme.qml"
shell="$repo/versions/default/shell.qml"
workspace="$repo/versions/default/panels/WorkspacePanel.qml"
surface="$repo/versions/default/modules/PopupSurface.qml"

popup_flags=(
  menuVisible themeSwitcherVisible wallpaperSwitcherVisible clipboardVisible
  emojiPickerVisible captureVisible appLauncherVisible calendarVisible cpuVisible
  aiUsageVisible volVisible controlVisible networkVisible
  bluetoothVisible batteryVisible mprisVisible workspaceVisible imagePickerVisible
  mediaBrowserVisible notifVisible powerProfileVisible shellUpdateVisible trayVisible
  trayMenuVisible tailscaleVisible
)

require_literal 'property bool _closingPopups: false' "$theme"
require_literal 'function closePopups(except)' "$theme"
require_literal 'function popupOpened(prop)' "$theme"
require_literal 'if (!_closingPopups && theme[prop]) closePopups(prop)' "$theme"
require_literal 'hideTooltip()' "$theme"

for flag in "${popup_flags[@]}"; do
  require_literal "if (except !== \"$flag\") $flag = false" "$theme"
done

# Opening one popup closes all others without recursively re-entering closePopups.
require_literal '_closingPopups = true' "$theme"
require_literal '_closingPopups = false' "$theme"
require_literal 'onWorkspaceVisibleChanged: popupOpened("workspaceVisible")' "$theme"

# Popup placement uses a validated real screen and per-screen bar anchors.
require_literal 'property var activePopupScreen: null' "$theme"
require_literal 'property string activePopupScreenName: ""' "$theme"
require_literal 'function activatePopupScreen(screen)' "$theme"
require_literal 'if (!screen || screen.name === "") return' "$theme"
require_literal 'function activateFocusedPopupScreen()' "$theme"
require_literal 'candidate.width > 0' "$theme"
require_literal 'candidate.height > 0' "$theme"
require_literal 'function publishBarAnchors(screenName, anchors)' "$theme"
require_literal 'if (screenName === activePopupScreenName) applyActiveBarAnchors()' "$theme"

# Keyboard popups close rather than migrate when focus moves to another monitor.
require_literal 'if (!theme.keyboardPopupVisible || theme.activePopupScreenName === "") return' "$theme"
require_literal 'if (focusedName !== "" && focusedName !== theme.activePopupScreenName)' "$theme"
require_literal 'theme.closePopups()' "$theme"

# Invalid/disappeared outputs close popups before selecting a valid fallback.
require_literal 'function ensureActivePopupScreen()' "$shell"
require_literal 'if (theme.anyPopupVisible) theme.closePopups()' "$shell"
require_literal 'theme.activatePopupScreen(barScreens[0])' "$shell"

# Secondary-screen dismissal is deliberately disabled for keyboard popups and
# never covers the active popup screen.
require_literal 'component PopupDismissLayer: PanelWindow' "$shell"
require_literal 'WlrLayershell.namespace: "quickshell-popup-dismiss"' "$shell"
require_literal 'dismissLayer.root.closePopups()' "$shell"
require_literal '&& !root.keyboardPopupVisible' "$shell"
require_literal '&& !root.isActivePopupScreenName(targetScreen.name)' "$shell"

# Shared surface owns only mechanics proven equivalent by the baseline audit.
require_literal 'screen: root.activePopupScreen' "$surface"
require_literal 'anchors { top: true; bottom: true; left: true; right: true }' "$surface"
require_literal 'exclusionMode: ExclusionMode.Ignore' "$surface"
require_literal 'WlrLayershell.layer: WlrLayer.Overlay' "$surface"
require_literal 'WlrLayershell.namespace: layerNamespace' "$surface"
require_literal 'property real reveal: opened ? 1 : 0' "$surface"
require_literal 'duration: surface.opened ? surface.openDuration : surface.closeDuration' "$surface"
require_literal 'visible: reveal > 0.001' "$surface"
require_literal 'WlrLayershell.keyboardFocus: opened ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None' "$surface"

# Workspace is the Phase 2 pilot. Feature behavior remains local.
require_literal 'PopupSurface {' "$workspace"
require_literal 'opened: root.workspaceVisible' "$workspace"
require_literal 'layerNamespace: "omarchy-workspace"' "$workspace"
require_literal 'MouseArea { anchors.fill: parent; onClicked: root.workspaceVisible = false }' "$workspace"
require_literal 'MouseArea { anchors.fill: parent; onClicked: {} }' "$workspace"
require_literal 'focus: root.workspaceVisible' "$workspace"
require_regex 'Qt.Key_Escape.*root.workspaceVisible = false.*event.accepted = true' "$workspace"
require_literal 'root.gotoWorkspace(modelData.id)' "$workspace"

panel_count="$(rg -l '^PanelWindow \{' "$repo"/versions/default/panels/*.qml | wc -l)"
[[ "$panel_count" -eq 29 ]] || fail "expected 29 remaining direct PanelWindow panels, got $panel_count"

printf 'ok (isolated popup lifecycle contract: %s flags, Workspace pilot + %s direct panels)\n' "${#popup_flags[@]}" "$panel_count"
