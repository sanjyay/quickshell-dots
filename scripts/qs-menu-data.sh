#!/usr/bin/env bash
# Emits trusted, tab-separated rows for dynamic Super Menu submenus.
set -euo pipefail

source="${1:-}"
home="${HOME:?}"
omarchy_themes="${OMARCHY_PATH:-$home/.local/share/omarchy}/themes"

safe_name() { [[ "$1" =~ ^[A-Za-z0-9._-]+$ ]]; }
emit() { printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$4" "${5:-}" "${6:-}"; }

case "$source" in
  fonts)
    while IFS= read -r font; do
      [[ -n "$font" && "$font" != *$'\t'* && "$font" != *$'\n'* ]] || continue
      emit "•" "$font" "Set system monospace font" "style-font-set" "$font"
    done < <(omarchy-font-list 2>/dev/null | LC_ALL=C sort -fu)
    ;;
  unlocks)
    declare -A seen=()
    for root in "$home/.config/omarchy/themes" "$omarchy_themes"; do
      [[ -d "$root" ]] || continue
      for dir in "$root"/*; do
        name="${dir##*/}"
        [[ -d "$dir" && -f "$dir/preview-unlock.png" && -z "${seen[$name]:-}" ]] || continue
        safe_name "$name" || continue
        seen[$name]=1
        emit "•" "$name" "Use as boot/unlock theme" "style-unlock-theme" "$name" "$dir/preview-unlock.png"
      done
    done
    emit "•" "Default" "Restore Omarchy boot/unlock theme" "style-unlock-default"
    ;;
  hardware)
    emit "•" "Laptop Display" "Toggle the internal display" "hardware-laptop-display"
    emit "•" "Mirror Display" "Toggle internal display mirroring" "hardware-mirror-display"
    omarchy-hw-hybrid-gpu >/dev/null 2>&1 && emit "•" "Hybrid GPU" "Configure hybrid graphics" "hardware-hybrid-gpu"
    omarchy-hw-touchpad >/dev/null 2>&1 && emit "•" "Touchpad" "Toggle touchpad" "hardware-touchpad"
    omarchy-hw-touchscreen >/dev/null 2>&1 && emit "•" "Touchscreen" "Toggle touchscreen" "hardware-touchscreen"
    if omarchy-hw-dell-xps-haptic-touchpad >/dev/null 2>&1 && command -v dell-xps-touchpad-haptics >/dev/null 2>&1; then
      for level in low mid high; do emit "•" "Touchpad Haptics: $level" "Set haptic strength" "hardware-haptics" "$level"; done
    fi
    ;;
  *) exit 64 ;;
esac
