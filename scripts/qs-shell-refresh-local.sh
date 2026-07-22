#!/usr/bin/env bash
# Refresh the installed bar from a local source tree, then restart Quickshell.
set -euo pipefail

DEST="${QS_SHELL_DEST:-$HOME/.config/quickshell/bar}"
SRC="${QS_SHELL_SOURCE:-}"
[ "$DEST" != "/" ] && DEST="${DEST%/}"

if [ -z "$SRC" ] && [ -r "$DEST/.qsrise-source" ]; then
  SRC="$(tr -d '\n' < "$DEST/.qsrise-source")"
fi
if [ -n "$SRC" ] && [ ! -d "$SRC/versions/default" ]; then
  printf '%s\n' "QS-Shell: recorded source '$SRC' is unavailable; falling back to the deploy clone" >&2
  SRC=""
fi
if [ -z "$SRC" ] && [ -d "$HOME/.local/share/quickshell-dots/versions/default" ]; then
  SRC="$HOME/.local/share/quickshell-dots"
fi

note() { notify-send -a "QS-Shell" "$@" 2>/dev/null || true; }
fail() { note -u critical "Shell refresh failed" "$1"; exit 1; }

[ -n "$SRC" ] || fail "No source tree recorded. Re-run install.sh once."
[ -d "$SRC/versions/default" ] || fail "Missing $SRC/versions/default."
[ -d "$DEST" ] || fail "Installed bar not found at $DEST."

parent="$(dirname "$DEST")"
ts="$(date +%Y%m%d-%H%M%S)"
stage="$(mktemp -d -p "$parent" .qs-refresh.XXXXXX)"
backup="$DEST.refresh.$ts"
trap 'rm -rf "$stage" 2>/dev/null || true' EXIT

cp -r "$SRC/versions/default/." "$stage/"
[ -f "$DEST/quotes.txt" ] && cp -p "$DEST/quotes.txt" "$stage/quotes.txt"
printf 'default\n' > "$stage/.qsrise"
printf '%s\n' "$SRC" > "$stage/.qsrise-source"

pkill -f 'qs.* -c bar([[:space:]]|$)' 2>/dev/null || true
pkill -f "quickshell -p $DEST" 2>/dev/null || true
for _ in $(seq 1 30); do
  pgrep -f 'qs.* -c bar([[:space:]]|$)' >/dev/null 2>&1 || break
  sleep 0.1
done

mv "$DEST" "$backup"
mv "$stage" "$DEST"
trap - EXIT
rm -rf "$backup" 2>/dev/null || true
if [ -f "$SRC/scripts/ensure-hypr-launcher-binding.sh" ]; then
  bash "$SRC/scripts/ensure-hypr-launcher-binding.sh" || true
fi
if [ -f "$SRC/scripts/ensure-hypr-switcher-blur-rules.sh" ]; then
  bash "$SRC/scripts/ensure-hypr-switcher-blur-rules.sh" || true
fi
setsid qs -n -d -c bar >/dev/null 2>&1 < /dev/null &
note "Shell refreshed" "Reloaded from $SRC."
