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
    qs -c bar kill >/dev/null 2>&1 || true
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
    pkill -x swayosd-server >/dev/null 2>&1 || true
}

QS_BIND_BEGIN="# >>> quickshell-rise managed media bindings >>>"
QS_BIND_END="# <<< quickshell-rise managed media bindings <<<"

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
            && qs -c bar ipc call health ping >/dev/null 2>&1; then
            return 0
        fi
    done
    return 1
}

start_omarchy() {
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
    stop_omarchy_ui
    set_launcher_binding omarchy
    hyprctl reload >/dev/null 2>&1 || true
    start_omarchy
    write_mode omarchy
    info "Omarchy UI restored"
}

switch_to_quickshell() {
    previous="$(cat "$STATE_FILE" 2>/dev/null || printf 'omarchy')"
    install_qs_media_bindings
    set_launcher_binding quickshell
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
