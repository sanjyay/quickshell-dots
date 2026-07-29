#!/usr/bin/env bash
set -euo pipefail

repo="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
panel="$repo/versions/default/panels/HistoryPanel.qml"
bar="$repo/versions/rise/Bar.qml"
installer="$repo/install.sh"

grep -Fq 'HistoryPanel { root: theme }' "$bar"
grep -Fq 'target: "quickshell-rise-clipboard"' "$bar"
grep -Fq '/.local/state/omarchy/clipboard-history.json' "$panel"
grep -Fq 'omarchy-clipboard-paste-text' "$panel"
grep -Fq 'omarchy-clipboard-paste-file' "$panel"
grep -Fq 'var fallbackNow = Date.now() / 1000' "$panel"
grep -Fq 'fallbackNow - i * 60' "$panel"
grep -Fq 'hl.unbind("SUPER + CTRL + V")' "$installer"
grep -Fq 'Quickshell Rise clipboard history' "$installer"

if grep -Eqi 'elephant|qs -c bar|quickshell -c bar' "$panel" "$bar"; then
  echo "FAIL: retired clipboard backend or standalone Quickshell path found" >&2
  exit 1
fi

echo "PASS: Rise history uses the native Quattro clipboard store and binding"
