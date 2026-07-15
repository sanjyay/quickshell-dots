#!/usr/bin/env bash
# Quickshell Rise — profile-owned media-key actions and OSD bridge.
set -euo pipefail

STATE_FILE="${XDG_STATE_HOME:-$HOME/.local/state}/qs-rise/mode"
QS_CONFIG="bar"
OSD_FILE="${XDG_RUNTIME_DIR:-/tmp}/qs-rise-osd.json"

[[ "$(cat "$STATE_FILE" 2>/dev/null || printf omarchy)" == quickshell ]] || exit 0

show_osd() {
    local payload tmp
    payload="$(printf '{\"kind\":\"%s\",\"value\":\"%s\",\"detail\":\"%s\"}' \
        "$1" "$2" "${3:-}")"
    tmp="${OSD_FILE}.tmp.$$"
    printf '%s\n' "$payload" > "$tmp"
    mv -f "$tmp" "$OSD_FILE"
    qs -c "$QS_CONFIG" ipc call osd show >/dev/null 2>&1 || true
}

volume_value() { pamixer --get-volume 2>/dev/null || printf 0; }
volume_muted() { pamixer --get-mute 2>/dev/null || printf false; }

volume_action() {
    local action="$1" step=5
    [[ "$action" == precise-up || "$action" == precise-down ]] && step=1
    case "$action" in
        up|precise-up) pamixer --increase "$step" --allow-boost ;;
        down|precise-down) pamixer --decrease "$step" ;;
        mute) pamixer --toggle-mute ;;
        *) exit 2 ;;
    esac
    local value
    value="$(volume_value)"
    show_osd volume "$value" "$(volume_muted)"
}

mic_action() {
    pamixer --default-source --toggle-mute
    show_osd microphone "$(pamixer --default-source --get-volume 2>/dev/null || printf 0)" \
        "$(pamixer --default-source --get-mute 2>/dev/null || printf false)"
}

backlight_device() {
    brightnessctl -l 2>/dev/null | sed -n "s/^Device '\([^']*\)' of class 'backlight':/\1/p" | head -n1
}

backlight_action() {
    local action="$1" device value
    device="$(backlight_device)"
    [[ -n "$device" ]] || exit 1
    case "$action" in
        up) brightnessctl -d "$device" set +5% >/dev/null ;;
        down) brightnessctl -d "$device" set 5%- >/dev/null ;;
        max) brightnessctl -d "$device" set 100% >/dev/null ;;
        min) brightnessctl -d "$device" set 1% >/dev/null ;;
        precise-up) brightnessctl -d "$device" set +1% >/dev/null ;;
        precise-down) brightnessctl -d "$device" set 1%- >/dev/null ;;
        *) exit 2 ;;
    esac
    value="$(brightnessctl -d "$device" -m | cut -d, -f4 | tr -d '%')"
    show_osd brightness "${value:-0}"
}

keyboard_action() {
    local action="$1" device current max value
    device="$(find /sys/class/leds -maxdepth 1 -type d -name '*kbd_backlight*' -printf '%f\n' 2>/dev/null | head -n1)"
    [[ -n "$device" ]] || exit 1
    current="$(brightnessctl -d "$device" get)"
    max="$(brightnessctl -d "$device" max)"
    case "$action" in
        up) current=$((current + max / 10)); (( current > max )) && current=$max ;;
        down) current=$((current - max / 10)); (( current < 0 )) && current=0 ;;
        *) exit 2 ;;
    esac
    brightnessctl -d "$device" set "$current" >/dev/null
    value=$((current * 100 / max))
    show_osd keyboard "$value"
}

media_action() {
    case "$1" in
        next) playerctl next ;;
        previous) playerctl previous ;;
        play-pause) playerctl play-pause ;;
        *) exit 2 ;;
    esac
    show_osd media "" "$1"
}

case "${1:-}" in
    volume) volume_action "${2:-}" ;;
    mic) mic_action ;;
    brightness) backlight_action "${2:-}" ;;
    keyboard) keyboard_action "${2:-}" ;;
    media) media_action "${2:-}" ;;
    *) printf 'usage: qs-rise-input {volume|mic|brightness|keyboard|media} ...\n' >&2; exit 2 ;;
esac
