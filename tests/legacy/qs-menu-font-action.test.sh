#!/usr/bin/env bash
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf -- "$tmp"' EXIT

mkdir -p "$tmp/bin"
printf '%s\n' '#!/usr/bin/env bash' 'printf "%s\n" "Adwaita Mono"' > "$tmp/bin/omarchy-font-list"
printf '%s\n' '#!/usr/bin/env bash' \
  'omarchy-restart-waybar' \
  'omarchy-restart-swayosd' \
  'printf "%s" "$1" > "$TEST_FONT_RESULT"' > "$tmp/bin/omarchy-font-set"
printf '%s\n' '#!/usr/bin/env bash' \
  'printf "%s\n" "$*" > "$TEST_QS_RESULT"' > "$tmp/bin/qs"
chmod 755 "$tmp/bin/omarchy-font-list" "$tmp/bin/omarchy-font-set" "$tmp/bin/qs"

PATH="$tmp/bin:$PATH" TEST_FONT_RESULT="$tmp/font" TEST_QS_RESULT="$tmp/qs" \
  bash "$repo/scripts/qs-menu-action.sh" style-font-set "Adwaita Mono"

[[ "$(cat "$tmp/font")" == "Adwaita Mono" ]] || { echo "FAIL: font setter did not receive selection" >&2; exit 1; }
[[ "$(cat "$tmp/qs")" == '-c bar ipc call -- theme setFont Adwaita Mono' ]] || { echo "FAIL: Quickshell font IPC was not sent" >&2; exit 1; }
printf 'ok\n'
