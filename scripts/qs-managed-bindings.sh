#!/usr/bin/env bash
# Deterministic owner for Quickshell Rise's managed Hyprland binding content.
set -euo pipefail

bindings="${HYPR_BINDINGS_CONF:-${HYPR_KEYBINDINGS_CONF:-$HOME/.config/hypr/bindings.conf}}"
menu_begin="# >>> quickshell-rise managed menu bindings >>>"
menu_end="# <<< quickshell-rise managed menu bindings <<<"
media_begin="# >>> quickshell-rise managed media bindings >>>"
media_end="# <<< quickshell-rise managed media bindings <<<"
notif_begin="# >>> quickshell-rise managed notification bindings >>>"
notif_end="# <<< quickshell-rise managed notification bindings <<<"
toggle_line="bindd = SUPER SHIFT, SPACE, Toggle desktop provider, exec, bash -lc 'if [[ \"\$(qs-mode status)\" == quickshell ]]; then qs-mode omarchy; else qs-mode quickshell; fi'"

usage() {
  printf 'usage: qs-managed-bindings {ensure-launcher|profile quickshell|profile omarchy|remove}\n' >&2
  exit 2
}

new_temp() {
  mkdir -p "$(dirname "$bindings")"
  mktemp "$(dirname "$bindings")/.qs-rise-bindings.XXXXXX"
}

replace_with_temp() {
  local tmp="$1"
  if grep -q '[^[:space:]]' "$tmp"; then
    mv "$tmp" "$bindings"
  else
    rm -f "$tmp" "$bindings"
  fi
}

strip_managed_content() {
  [[ -f "$bindings" ]] || return 0
  local remove_exact="${1:-no}" tmp in_block=0 line
  tmp="$(new_temp)"

  while IFS= read -r line || [[ -n "$line" ]]; do
    case "$line" in
      "$menu_begin"|"$media_begin"|"$notif_begin") in_block=1; continue ;;
      "$menu_end"|"$media_end"|"$notif_end") in_block=0; continue ;;
    esac
    [[ "$in_block" -eq 1 ]] && continue

    if [[ "$remove_exact" == yes ]]; then
      case "$line" in
        "unbind = SUPER, SPACE"|\
        "bind = SUPER, SPACE, exec, qs -c bar ipc call launcher open"|\
        "unbind = SUPER SHIFT, SPACE"|\
        "$toggle_line"|\
        "bind = SUPER CTRL SHIFT, SPACE, exec, qs -c bar ipc call themeSwitcher toggle"|\
        "unbind = SUPER CTRL, SPACE"|\
        "bindd = SUPER CTRL, SPACE, Quickshell wallpaper switcher, exec, qs -c bar ipc call -- wallpaperSwitcher toggle"|\
        "bindd = SUPER CTRL, SPACE, Wallpaper picker, exec, qs -c bar ipc call picker wallpaper"|\
        "bindd  = SUPER CTRL, SPACE,       Wallpaper picker, exec, qs -c bar ipc call picker wallpaper"|\
        "bindd = SUPER SHIFT, SPACE, Refresh Quickshell bar, exec, bash -lc 'qs -c bar kill; sleep 0.2; qs -n -d -c bar'"|\
        "bindd = SUPER SHIFT, SPACE, Toggle-refresh Quickshell bar, exec, bash -lc 'qs -c bar kill >/dev/null 2>&1 || true; sleep 0.35; qs -n -d -c bar'"|\
        "bindd = SUPER SHIFT, SPACE, Toggle Quickshell bar, exec, bash -lc 'if qs list --all 2>/dev/null | grep -q \"$HOME/.config/quickshell/bar/shell.qml\"; then qs -c bar kill >/dev/null 2>&1 || true; else qs -n -d -c bar; fi'")
          continue
          ;;
      esac
    elif [[ "$remove_exact" == profile ]]; then
      case "$line" in
        "unbind = SUPER, SPACE"|\
        "bind = SUPER, SPACE, exec, qs -c bar ipc call launcher open"|\
        "bindd = SUPER, SPACE, Launch apps, exec, omarchy-launch-walker"|\
        "unbind = SUPER SHIFT, SPACE"|\
        "bind = SUPER CTRL SHIFT, SPACE, exec, qs -c bar ipc call themeSwitcher toggle"|\
        "unbind = SUPER CTRL, SPACE"|\
        "bindd = SUPER CTRL, SPACE, Quickshell wallpaper switcher, exec, qs -c bar ipc call -- wallpaperSwitcher toggle"|\
        "bindd = SUPER CTRL, SPACE, Wallpaper picker, exec, qs -c bar ipc call picker wallpaper"|\
        "bindd  = SUPER CTRL, SPACE,       Wallpaper picker, exec, qs -c bar ipc call picker wallpaper")
          continue
          ;;
      esac
    else
      case "$line" in
        "bind = SUPER CTRL SHIFT, SPACE, exec, qs -c bar ipc call themeSwitcher toggle"|\
        "bindd = SUPER CTRL, SPACE, Quickshell wallpaper switcher, exec, qs -c bar ipc call -- wallpaperSwitcher toggle"|\
        "bindd = SUPER CTRL, SPACE, Wallpaper picker, exec, qs -c bar ipc call picker wallpaper"|\
        "bindd  = SUPER CTRL, SPACE,       Wallpaper picker, exec, qs -c bar ipc call picker wallpaper")
          continue
          ;;
      esac
    fi

    printf '%s\n' "$line" >> "$tmp"
  done < "$bindings"

  replace_with_temp "$tmp"
}

append_quickshell_menu() {
  cat >> "$bindings" <<'EOF'

# >>> quickshell-rise managed menu bindings >>>
unbind = SUPER, SPACE
unbind = SUPER ALT, SPACE
unbind = SUPER SHIFT, code:201
unbind = SUPER, ESCAPE
unbind = , XF86PowerOff
unbind = SUPER CTRL, V
unbind = SUPER CTRL, E
unbind = SUPER CTRL, C
unbind = , PRINT
unbind = ALT, PRINT
unbind = ALT CTRL, PRINT
unbind = SUPER, PRINT
unbind = SUPER CTRL, PRINT
bind = SUPER, SPACE, exec, qs -c bar ipc call -- launcher open
unbind = SUPER CTRL SHIFT, SPACE
bind = SUPER CTRL SHIFT, SPACE, exec, qs -c bar ipc call themeSwitcher toggle
unbind = SUPER CTRL, SPACE
bindd = SUPER CTRL, SPACE, Quickshell wallpaper switcher, exec, qs -c bar ipc call -- wallpaperSwitcher toggle
# Right Alt is a keysym, so this installed Hyprland version requires a
# keysym-combination bind to distinguish it from left Alt.
binds = Super_L&Alt_R, SPACE, exec, qs -c bar ipc call -- menu open root
bindd = SUPER SHIFT, code:201, Quickshell menu, exec, qs -c bar ipc call -- menu open root
bindd = SUPER, ESCAPE, Quickshell power menu, exec, qs -c bar ipc call -- menu open system
bindd = , XF86PowerOff, Quickshell power menu, exec, qs -c bar ipc call -- menu open system
bindd = SUPER CTRL, V, Quickshell clipboard, exec, qs -c bar ipc call -- clipboard open
bindd = SUPER CTRL, E, Quickshell emoji picker, exec, qs -c bar ipc call -- emoji open
bindd = SUPER CTRL, C, Quickshell capture menu, exec, qs -c bar ipc call -- capture open
bindd = , PRINT, Quickshell screenshot, exec, qs-capture screenshot
bindd = ALT, PRINT, Quickshell screenrecording options, exec, qs -c bar ipc call -- capture recording
bindd = ALT CTRL, PRINT, Quickshell capture menu, exec, qs -c bar ipc call -- capture open
bindd = SUPER, PRINT, Quickshell color picker, exec, qs -c bar ipc call -- capture color
bindd = SUPER CTRL, PRINT, Quickshell text extraction, exec, qs -c bar ipc call -- capture text
# Scratch workspace: Omarchy defines this as special:scratchpad.
binds = Super_L&Alt_R, S, movetoworkspacesilent, special:scratchpad
# <<< quickshell-rise managed menu bindings <<<
EOF
}

append_omarchy_menu() {
  cat >> "$bindings" <<'EOF'

# >>> quickshell-rise managed menu bindings >>>
unbind = SUPER, SPACE
unbind = SUPER ALT, SPACE
unbind = Super_L&Alt_R, SPACE
unbind = Super_L&Alt_R, S
unbind = SUPER SHIFT, code:201
unbind = SUPER, ESCAPE
unbind = , XF86PowerOff
unbind = SUPER CTRL, V
unbind = SUPER CTRL, E
unbind = SUPER CTRL, C
unbind = , PRINT
unbind = ALT, PRINT
unbind = ALT CTRL, PRINT
unbind = SUPER, PRINT
unbind = SUPER CTRL, PRINT
bindd = SUPER, SPACE, Launch apps, exec, omarchy-launch-walker
bindd = SUPER ALT, SPACE, Omarchy menu, exec, omarchy-menu
bindd = SUPER SHIFT, code:201, Omarchy menu, exec, omarchy-menu
bindd = SUPER, ESCAPE, System menu, exec, omarchy-menu system
bindd = , XF86PowerOff, Power menu, exec, omarchy-menu system
bindd = SUPER CTRL, V, Clipboard manager, exec, omarchy-launch-walker -m clipboard
bindd = SUPER CTRL, E, Emoji picker, exec, omarchy-launch-walker -m symbols
bindd = SUPER CTRL, C, Capture menu, exec, omarchy-menu capture
bindd = , PRINT, Screenshot, exec, omarchy-capture-screenshot
bindd = ALT, PRINT, Screenrecording, exec, omarchy-menu screenrecord
bindd = SUPER, PRINT, Color picker, exec, pkill hyprpicker || hyprpicker -a
bindd = SUPER CTRL, PRINT, Extract text, exec, omarchy-capture-text-extraction
# <<< quickshell-rise managed menu bindings <<<
EOF
}

append_quickshell_media() {
  cat >> "$bindings" <<'EOF'

# >>> quickshell-rise managed media bindings >>>
unbind = , XF86AudioRaiseVolume
unbind = , XF86AudioLowerVolume
unbind = , XF86AudioMute
unbind = , XF86AudioMicMute
unbind = , XF86MonBrightnessUp
unbind = , XF86MonBrightnessDown
unbind = SHIFT, XF86MonBrightnessUp
unbind = SHIFT, XF86MonBrightnessDown
unbind = , XF86KbdBrightnessUp
unbind = , XF86KbdBrightnessDown
unbind = , XF86KbdLightOnOff
unbind = , XF86TouchpadOn
unbind = , XF86TouchpadOff
unbind = , XF86TouchpadToggle
unbind = , XF86AudioCycleOutput
unbind = ALT, XF86AudioRaiseVolume
unbind = ALT, XF86AudioLowerVolume
unbind = ALT, XF86MonBrightnessUp
unbind = ALT, XF86MonBrightnessDown
unbind = , XF86AudioNext
unbind = , XF86AudioPause
unbind = , XF86AudioPlay
unbind = , XF86AudioPrev
bindeld = , XF86AudioRaiseVolume, Quickshell volume up, exec, qs-rise-input volume up
bindeld = , XF86AudioLowerVolume, Quickshell volume down, exec, qs-rise-input volume down
bindeld = , XF86AudioMute, Quickshell volume mute, exec, qs-rise-input volume mute
bindeld = , XF86AudioMicMute, Quickshell microphone mute, exec, qs-rise-input mic mute
bindeld = , XF86MonBrightnessUp, Quickshell brightness up, exec, qs-rise-input brightness up
bindeld = , XF86MonBrightnessDown, Quickshell brightness down, exec, qs-rise-input brightness down
bindeld = SHIFT, XF86MonBrightnessUp, Quickshell brightness max, exec, qs-rise-input brightness max
bindeld = SHIFT, XF86MonBrightnessDown, Quickshell brightness min, exec, qs-rise-input brightness min
bindeld = , XF86KbdBrightnessUp, Quickshell keyboard brightness up, exec, qs-rise-input keyboard up
bindeld = , XF86KbdBrightnessDown, Quickshell keyboard brightness down, exec, qs-rise-input keyboard down
bindeld = , XF86KbdLightOnOff, Quickshell keyboard brightness cycle, exec, qs-rise-input keyboard cycle
bindeld = , XF86TouchpadOn, Quickshell touchpad on, exec, qs-rise-input touchpad on
bindeld = , XF86TouchpadOff, Quickshell touchpad off, exec, qs-rise-input touchpad off
bindeld = , XF86TouchpadToggle, Quickshell touchpad toggle, exec, qs-rise-input touchpad toggle
bindeld = , XF86AudioCycleOutput, Quickshell audio output, exec, qs-rise-input audio-output
bindnr = , Caps_Lock, exec, qs-rise-input lock "Caps Lock"
bindnr = , Num_Lock, exec, qs-rise-input lock "Num Lock"
bindeld = ALT, XF86AudioRaiseVolume, Quickshell volume up precise, exec, qs-rise-input volume precise-up
bindeld = ALT, XF86AudioLowerVolume, Quickshell volume down precise, exec, qs-rise-input volume precise-down
bindeld = ALT, XF86MonBrightnessUp, Quickshell brightness up precise, exec, qs-rise-input brightness precise-up
bindeld = ALT, XF86MonBrightnessDown, Quickshell brightness down precise, exec, qs-rise-input brightness precise-down
bindld = , XF86AudioNext, Quickshell next track, exec, qs-rise-input media next
bindld = , XF86AudioPause, Quickshell media pause, exec, qs-rise-input media play-pause
bindld = , XF86AudioPlay, Quickshell media play, exec, qs-rise-input media play-pause
bindld = , XF86AudioPrev, Quickshell previous track, exec, qs-rise-input media previous
# <<< quickshell-rise managed media bindings <<<
EOF
}

append_quickshell_notifications() {
  cat >> "$bindings" <<'EOF'

# >>> quickshell-rise managed notification bindings >>>
bindd = SUPER, COMMA, Dismiss notification, exec, qs -c bar ipc call -- notifications dismiss
bindd = SUPER SHIFT, COMMA, Dismiss all notifications, exec, qs -c bar ipc call -- notifications dismissAll
bindd = SUPER CTRL, COMMA, Toggle notification DND, exec, qs -c bar ipc call -- notifications toggleDnd
bindd = SUPER ALT, COMMA, Invoke notification, exec, qs -c bar ipc call -- notifications invoke
# <<< quickshell-rise managed notification bindings <<<
EOF
}

ensure_launcher() {
  mkdir -p "$(dirname "$bindings")"
  [[ -e "$bindings" ]] || : > "$bindings"

  local tmp line
  tmp="$(new_temp)"
  while IFS= read -r line || [[ -n "$line" ]]; do
    case "$line" in
      "unbind = SUPER, SPACE"|\
      "bind = SUPER, SPACE, exec, qs -c bar ipc call launcher open"|\
      "unbind = SUPER SHIFT, SPACE"|\
      "$toggle_line"|\
      "bindd = SUPER SHIFT, SPACE, Refresh Quickshell bar, exec, bash -lc 'qs -c bar kill; sleep 0.2; qs -n -d -c bar'"|\
      "bindd = SUPER SHIFT, SPACE, Toggle-refresh Quickshell bar, exec, bash -lc 'qs -c bar kill >/dev/null 2>&1 || true; sleep 0.35; qs -n -d -c bar'")
        continue
        ;;
    esac
    printf '%s\n' "$line" >> "$tmp"
  done < "$bindings"

  for line in \
    'unbind = SUPER, SPACE' \
    'bind = SUPER, SPACE, exec, qs -c bar ipc call launcher open' \
    'unbind = SUPER SHIFT, SPACE' \
    "$toggle_line"
  do
    printf '%s\n' "$line" >> "$tmp"
  done
  mv "$tmp" "$bindings"
}

apply_profile() {
  local profile="$1"
  [[ "$profile" == quickshell || "$profile" == omarchy ]] || usage
  [[ -f "$bindings" ]] || return 0

  strip_managed_content profile
  if [[ "$profile" == quickshell ]]; then
    append_quickshell_media
    append_quickshell_notifications
    append_quickshell_menu
  else
    append_omarchy_menu
  fi
}

case "${1:-}" in
  ensure-launcher)
    [[ $# -eq 1 ]] || usage
    ensure_launcher
    ;;
  profile)
    [[ $# -eq 2 ]] || usage
    apply_profile "$2"
    ;;
  remove)
    [[ $# -eq 1 ]] || usage
    strip_managed_content yes
    ;;
  *) usage ;;
esac
