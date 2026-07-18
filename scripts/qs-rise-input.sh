#!/usr/bin/env bash
# Quickshell Rise — profile-owned media-key actions and OSD bridge.
set -euo pipefail

STATE_FILE="${XDG_STATE_HOME:-$HOME/.local/state}/qs-rise/mode"
QS_CONFIG="bar"

[[ "$(cat "$STATE_FILE" 2>/dev/null || printf omarchy)" == quickshell ]] || exit 0

show_osd() {
    qs -c "$QS_CONFIG" ipc call -- osd show "$1" "$2" "${3:-}" "${4:-}" "${5:-}" >/dev/null 2>&1 || true
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
        cycle) current=$((current >= max ? 0 : current + max / 3)); (( current > max )) && current=$max ;;
        *) exit 2 ;;
    esac
    brightnessctl -d "$device" set "$current" >/dev/null
    value=$((current * 100 / max))
    show_osd keyboard "$value"
}

touchpad_action() {
    local action="$1" state
    case "$action" in
        on) state=true ;; off) state=false ;;
        toggle) state="$(hyprctl getoption device:touchpad:enabled -j 2>/dev/null | sed -n 's/.*"int"[[:space:]]*:[[:space:]]*\([01]\).*/\1/p')"; [[ "$state" == 1 ]] && state=false || state=true ;;
        *) exit 2 ;;
    esac
    hyprctl keyword device:touchpad:enabled "$state" >/dev/null
    show_osd touchpad "" "$([[ "$state" == true ]] && printf Enabled || printf Disabled)"
}

state_action() { show_osd "$1" "${2:-}" "${3:-}" "${4:-}" "${5:-}"; }

lock_action() {
    local key="$1" state=Off
    command -v xset >/dev/null 2>&1 && state="$(xset q 2>/dev/null | sed -n "s/.*${key}:[[:space:]]*\(on\|off\).*/\1/ip" | head -n1)"
    show_osd "${key,,}" "" "${key} ${state^}"
}

media_action() {
    local action="$1" before="" metadata="" title="" artist="" detail="Media"
    before="$(playerctl metadata --format $'{{xesam:title}}\t{{xesam:artist}}' 2>/dev/null | head -n1 || true)"
    case "$1" in
        next) playerctl next ;;
        previous) playerctl previous ;;
        play-pause) playerctl play-pause ;;
        *) exit 2 ;;
    esac

    # Track changes are asynchronous for several MPRIS players. Give metadata a
    # short bounded window to advance so the OSD describes the song that is now
    # playing instead of the transport command that was pressed.
    for _ in {1..10}; do
        metadata="$(playerctl metadata --format $'{{xesam:title}}\t{{xesam:artist}}' 2>/dev/null | head -n1 || true)"
        [[ -n "$metadata" && ( "$action" == play-pause || "$metadata" != "$before" ) ]] && break
        sleep 0.05
    done

    if [[ -n "$metadata" ]]; then
        IFS=$'\t' read -r title artist <<< "$metadata"
        if [[ -n "$title" && -n "$artist" ]]; then detail="$title"$'\n'"$artist"
        elif [[ -n "$title" ]]; then detail="$title"
        elif [[ -n "$artist" ]]; then detail="$artist"
        fi
    fi
    show_osd media "" "$detail" "󰎈"
}

audio_output_action() {
    omarchy-audio-output-switch
    show_osd audio-output "" "Audio output switched"
}

case "${1:-}" in
    volume) volume_action "${2:-}" ;;
    mic) mic_action ;;
    brightness) backlight_action "${2:-}" ;;
    keyboard) keyboard_action "${2:-}" ;;
    media) media_action "${2:-}" ;;
    audio-output) audio_output_action ;;
    touchpad) touchpad_action "${2:-toggle}" ;;
    lock) lock_action "${2:-Caps Lock}" ;;
    osd) shift; state_action "$@" ;;
    *) printf 'usage: qs-rise-input {volume|mic|brightness|keyboard|media|audio-output|touchpad|lock|osd} ...\n' >&2; exit 2 ;;
esac
