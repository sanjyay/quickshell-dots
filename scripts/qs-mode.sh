#!/usr/bin/env bash
# Switch the desktop UI provider stack between Quickshell and Omarchy defaults.
set -euo pipefail

STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/qs-rise"
STATE_FILE="$STATE_DIR/mode"
DEST="$HOME/.config/quickshell/bar"
BINDINGS="${HYPR_BINDINGS_CONF:-${HYPR_KEYBINDINGS_CONF:-$HOME/.config/hypr/bindings.conf}}"

info() { printf 'qs-mode: %s\n' "$*"; }
err() { printf 'qs-mode: %s\n' "$*" >&2; }

mkdir -p "$STATE_DIR"

write_mode() {
    printf '%s\n' "$1" > "$STATE_FILE"
}

stop_quickshell() {
    # `qs -c bar kill` can block when several instances share a config.
    # Terminate only the PIDs registered to this exact config.
    local listed
    listed="$(qs list -c bar -j 2>/dev/null || true)"
    bar_pids=()
    if jq -e 'type == "array"' >/dev/null 2>&1 <<< "$listed"; then
        mapfile -t bar_pids < <(jq -r --arg config "$DEST/shell.qml" \
            '.[] | select(.config_path == $config) | .pid' <<< "$listed")
    fi
    for pid in "${bar_pids[@]}"; do
        [[ "$pid" =~ ^[0-9]+$ ]] || continue
        pkill -TERM -P "$pid" >/dev/null 2>&1 || true
        kill -TERM "$pid" >/dev/null 2>&1 || true
    done
    for _ in {1..20}; do
        alive=false
        for pid in "${bar_pids[@]}"; do
            if [[ "$pid" =~ ^[0-9]+$ ]] && kill -0 "$pid" 2>/dev/null; then alive=true; break; fi
        done
        [[ "$alive" == true ]] || break
        sleep 0.1
    done
    pkill -f "quickshell -p $DEST" >/dev/null 2>&1 || true
}

stop_omarchy_ui() {
    pkill -x waybar >/dev/null 2>&1 || true
    pkill -x mako >/dev/null 2>&1 || true
    if systemctl --user stop app-walker@autostart.service >/dev/null 2>&1; then
        :
    else
        pkill -x walker >/dev/null 2>&1 || true
    fi
    systemctl --user disable --now swayosd-server.service >/dev/null 2>&1 || true
    systemctl --user mask --runtime swayosd-server.service >/dev/null 2>&1 || true
    pkill -x swayosd-server >/dev/null 2>&1 || true
}

QS_BIND_BEGIN="# >>> quickshell-rise managed media bindings >>>"
QS_BIND_END="# <<< quickshell-rise managed media bindings <<<"
QS_MENU_BEGIN="# >>> quickshell-rise managed menu bindings >>>"
QS_MENU_END="# <<< quickshell-rise managed menu bindings <<<"
QS_NOTIF_BEGIN="# >>> quickshell-rise managed notification bindings >>>"
QS_NOTIF_END="# <<< quickshell-rise managed notification bindings <<<"

remove_qs_media_bindings() {
    [[ -f "$BINDINGS" ]] || return 0
    local tmp
    tmp="$(mktemp)"
    awk -v begin="$QS_BIND_BEGIN" -v end="$QS_BIND_END" '
        $0 == begin { skip=1; next }
        $0 == end { skip=0; next }
        !skip { print }
    ' "$BINDINGS" > "$tmp"
    mv "$tmp" "$BINDINGS"
}

remove_qs_menu_bindings() {
    [[ -f "$BINDINGS" ]] || return 0
    local tmp
    tmp="$(mktemp)"
    awk -v begin="$QS_MENU_BEGIN" -v end="$QS_MENU_END" '
        $0 == begin { skip=1; next }
        $0 == end { skip=0; next }
        !skip { print }
    ' "$BINDINGS" > "$tmp"
    mv "$tmp" "$BINDINGS"
}

remove_standalone_theme_binding() {
    [[ -f "$BINDINGS" ]] || return 0
    local tmp
    tmp="$(mktemp)"
    awk '$0 != "bind = SUPER CTRL SHIFT, SPACE, exec, qs -c bar ipc call themeSwitcher toggle" &&
         $0 != "bindd = SUPER CTRL, SPACE, Quickshell wallpaper switcher, exec, qs -c bar ipc call -- wallpaperSwitcher toggle" &&
         $0 != "bindd = SUPER CTRL, SPACE, Wallpaper picker, exec, qs -c bar ipc call picker wallpaper" &&
         $0 != "bindd  = SUPER CTRL, SPACE,       Wallpaper picker, exec, qs -c bar ipc call picker wallpaper"' \
        "$BINDINGS" > "$tmp"
    mv "$tmp" "$BINDINGS"
}

install_qs_menu_bindings() {
    [[ -f "$BINDINGS" ]] || return 0
    remove_standalone_theme_binding
    remove_qs_menu_bindings
    cat >> "$BINDINGS" <<'EOF'

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

install_omarchy_menu_bindings() {
    [[ -f "$BINDINGS" ]] || return 0
    remove_standalone_theme_binding
    remove_qs_menu_bindings
    cat >> "$BINDINGS" <<'EOF'

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

install_qs_media_bindings() {
    [[ -f "$BINDINGS" ]] || return 0
    remove_qs_media_bindings
    cat >> "$BINDINGS" <<'EOF'

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

remove_qs_notification_bindings() {
    [[ -f "$BINDINGS" ]] || return 0
    local tmp; tmp="$(mktemp)"
    awk -v begin="$QS_NOTIF_BEGIN" -v end="$QS_NOTIF_END" '$0 == begin { skip=1; next } $0 == end { skip=0; next } !skip { print }' "$BINDINGS" > "$tmp"
    mv "$tmp" "$BINDINGS"
}

install_qs_notification_bindings() {
    [[ -f "$BINDINGS" ]] || return 0
    remove_qs_notification_bindings
    cat >> "$BINDINGS" <<'EOF'

# >>> quickshell-rise managed notification bindings >>>
bindd = SUPER, COMMA, Dismiss notification, exec, qs -c bar ipc call -- notifications dismiss
bindd = SUPER SHIFT, COMMA, Dismiss all notifications, exec, qs -c bar ipc call -- notifications dismissAll
bindd = SUPER CTRL, COMMA, Toggle notification DND, exec, qs -c bar ipc call -- notifications toggleDnd
bindd = SUPER ALT, COMMA, Invoke notification, exec, qs -c bar ipc call -- notifications invoke
# <<< quickshell-rise managed notification bindings <<<
EOF
}

set_launcher_binding() {
    [[ -f "$BINDINGS" ]] || return 0
    local tmp
    tmp="$(mktemp)"
    while IFS= read -r line || [[ -n "$line" ]]; do
        case "$line" in
            "unbind = SUPER, SPACE"|\
            "bind = SUPER, SPACE, exec, qs -c bar ipc call launcher open"|\
            "bindd = SUPER, SPACE, Launch apps, exec, omarchy-launch-walker")
                continue
                ;;
            *) printf '%s\n' "$line" >> "$tmp" ;;
        esac
    done < "$BINDINGS"
    {
        printf '%s\n' 'unbind = SUPER, SPACE'
        if [[ "$1" == quickshell ]]; then
            printf '%s\n' 'bind = SUPER, SPACE, exec, qs -c bar ipc call launcher open'
        else
            printf '%s\n' 'bindd = SUPER, SPACE, Launch apps, exec, omarchy-launch-walker'
        fi
    } >> "$tmp"
    mv "$tmp" "$BINDINGS"
}

start_quickshell() {
    [[ -f "$DEST/shell.qml" ]] || { err "Quickshell config is not installed at $DEST"; return 1; }
    setsid qs -n -d -c bar >/dev/null 2>&1 < /dev/null &
    for _ in {1..10}; do
        sleep 0.5
        if qs list --all 2>/dev/null | grep -Fq "$DEST/shell.qml" \
            && timeout 3 qs -n -c bar ipc call health ping >/dev/null 2>&1; then
            return 0
        fi
    done
    return 1
}

start_omarchy() {
    systemctl --user unmask swayosd-server.service >/dev/null 2>&1 || true
    if command -v omarchy >/dev/null 2>&1; then
        omarchy restart waybar >/dev/null 2>&1 || true
        omarchy restart walker >/dev/null 2>&1 || true
    else
        command -v waybar >/dev/null 2>&1 && setsid waybar >/dev/null 2>&1 < /dev/null &
    fi
    command -v mako >/dev/null 2>&1 && setsid mako >/dev/null 2>&1 < /dev/null &
    if systemctl --user enable --now swayosd-server.service >/dev/null 2>&1; then
        :
    else
        command -v swayosd-server >/dev/null 2>&1 && setsid swayosd-server >/dev/null 2>&1 < /dev/null &
    fi
}

switch_to_omarchy() {
    stop_quickshell
    remove_qs_media_bindings
    remove_qs_notification_bindings
    install_omarchy_menu_bindings
    stop_omarchy_ui
    hyprctl reload >/dev/null 2>&1 || true
    start_omarchy
    write_mode omarchy
    info "Omarchy UI restored"
}

switch_to_quickshell() {
    previous="$(cat "$STATE_FILE" 2>/dev/null || printf 'omarchy')"
    # Recreate the instance even when already in Quickshell mode so installs
    # and helper updates cannot leave stale QML/IPC handlers running.
    stop_quickshell
    install_qs_media_bindings
    install_qs_notification_bindings
    install_qs_menu_bindings
    hyprctl reload >/dev/null 2>&1 || true
    # Reloading Hyprland can re-run generated desktop autostart units (notably
    # Walker), so stop Omarchy presentation services after the reload as well.
    stop_omarchy_ui
    if start_quickshell; then
        write_mode quickshell
        info "Quickshell UI enabled"
    else
        err "Quickshell failed its startup health check; restoring $previous UI"
        switch_to_omarchy
        return 1
    fi
}

status() {
    mode="$(cat "$STATE_FILE" 2>/dev/null || printf 'omarchy')"
    printf '%s\n' "$mode"
}

case "${1:-status}" in
    quickshell) switch_to_quickshell ;;
    omarchy) switch_to_omarchy ;;
    status) status ;;
    *) err "usage: qs-mode {quickshell|omarchy|status}"; exit 2 ;;
esac
