#!/usr/bin/env bash
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
helper="$repo/scripts/qs-menu-data.sh"
tmp="$(mktemp -d)"
trap 'rm -rf -- "$tmp"' EXIT

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
expect() { [[ "$1" == *"$2"* ]] || fail "expected $2"; }
mock() { printf '%s\n' "$2" > "$tmp/bin/$1"; chmod 755 "$tmp/bin/$1"; }

mkdir -p "$tmp/bin" "$tmp/home/.config/omarchy/themes/Custom" "$tmp/omarchy/themes/Stock"
: > "$tmp/home/.config/omarchy/themes/Custom/preview-unlock.png"
: > "$tmp/omarchy/themes/Stock/preview-unlock.png"
mock omarchy-font-list '#!/usr/bin/env bash
printf "Mono A\\nMono B\\n"'
for command in omarchy-hw-hybrid-gpu omarchy-hw-touchpad; do mock "$command" '#!/usr/bin/env bash
exit 0'; done
for command in omarchy-hw-touchscreen omarchy-hw-dell-xps-haptic-touchpad; do mock "$command" '#!/usr/bin/env bash
exit 1'; done

fonts="$(PATH="$tmp/bin:$PATH" HOME="$tmp/home" OMARCHY_PATH="$tmp/omarchy" bash "$helper" fonts)"
expect "$fonts" $'Mono A\tSet system monospace font\tstyle-font-set\tMono A'
unlocks="$(PATH="$tmp/bin:$PATH" HOME="$tmp/home" OMARCHY_PATH="$tmp/omarchy" bash "$helper" unlocks)"
expect "$unlocks" $'Custom\tUse as boot/unlock theme\tstyle-unlock-theme\tCustom'
expect "$unlocks" $'Stock\tUse as boot/unlock theme\tstyle-unlock-theme\tStock'
expect "$unlocks" "$tmp/home/.config/omarchy/themes/Custom/preview-unlock.png"
expect "$unlocks" "$tmp/omarchy/themes/Stock/preview-unlock.png"
expect "$unlocks" $'Default\tRestore Omarchy boot/unlock theme\tstyle-unlock-default'
hardware="$(PATH="$tmp/bin:$PATH" HOME="$tmp/home" OMARCHY_PATH="$tmp/omarchy" bash "$helper" hardware)"
expect "$hardware" $'Laptop Display\tToggle the internal display\thardware-laptop-display'
expect "$hardware" $'Hybrid GPU\tConfigure hybrid graphics\thardware-hybrid-gpu'
expect "$hardware" $'Touchpad\tToggle touchpad\thardware-touchpad'

if PATH="$tmp/bin:$PATH" HOME="$tmp/home" OMARCHY_PATH="$tmp/omarchy" bash "$helper" invalid >/dev/null 2>&1; then
    fail 'unknown data source succeeded'
fi
printf 'ok\n'
