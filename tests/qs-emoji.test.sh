#!/usr/bin/env bash
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf -- "$tmp"' EXIT
mkdir -p "$tmp/bin"

printf '%s\n' '#!/usr/bin/env bash' 'printf "%s" "$*" > "$TEST_ELEPHANT_ARGS"' > "$tmp/bin/elephant"
printf '%s\n' '#!/usr/bin/env bash' 'shift; exec "$@"' > "$tmp/bin/timeout"
printf '%s\n' '#!/usr/bin/env bash' 'cat > "$TEST_WL_COPY"' > "$tmp/bin/wl-copy"
printf '%s\n' '#!/usr/bin/env bash' 'printf "%s" "$*" > "$TEST_HYPR_ARGS"' > "$tmp/bin/hyprctl"
chmod 755 "$tmp/bin/elephant" "$tmp/bin/timeout" "$tmp/bin/wl-copy" "$tmp/bin/hyprctl"

env PATH="$tmp/bin:$PATH" TEST_ELEPHANT_ARGS="$tmp/elephant" \
  bash "$repo/scripts/qs-emoji.sh" query "red heart" 25
[[ "$(cat "$tmp/elephant")" == 'query --json symbols;red heart;25' ]] || { echo 'FAIL: unsafe or malformed Elephant query' >&2; exit 1; }

env PATH="$tmp/bin:$PATH" TEST_WL_COPY="$tmp/copy" TEST_HYPR_ARGS="$tmp/hypr" \
  bash "$repo/scripts/qs-emoji.sh" select "👩🏽‍💻"
[[ "$(cat "$tmp/copy")" == "👩🏽‍💻" ]] || { echo 'FAIL: selected emoji was not copied exactly' >&2; exit 1; }
[[ "$(cat "$tmp/hypr")" == 'dispatch sendshortcut SHIFT,Insert,activewindow' ]] || { echo 'FAIL: paste shortcut was not dispatched' >&2; exit 1; }

if env PATH="$tmp/bin:$PATH" bash "$repo/scripts/qs-emoji.sh" select $'bad\nvalue' >/dev/null 2>&1; then
  echo 'FAIL: control characters were accepted' >&2
  exit 1
fi
printf 'ok\n'
