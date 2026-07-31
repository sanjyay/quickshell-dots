#!/usr/bin/env bash
set -euo pipefail

repo="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
theme="$repo/versions/default/Theme.qml"
ai_panel="$repo/versions/default/panels/AiUsagePanel.qml"
history="$repo/versions/default/panels/HistoryPanel.qml"

grep -Fq 'function formatDisplayDateTime(value, includeTime)' "$theme"
grep -Fq 'pad(date.getDate()) + "-" + pad(date.getMonth() + 1)' "$theme"
grep -Fq 'pad(date.getHours()) + ":" + pad(date.getMinutes())' "$theme"
grep -Fq 'root.formatDisplayDateTime(parsed, true)' "$ai_panel"
grep -Fq 'root.formatDisplayDateTime(startedAtMs, true)' "$history"

if rg -q 'MMM d|yyyy h:mm|toLocaleString\(Qt.locale\(\)' "$theme" "$ai_panel" "$history"; then
  echo 'FAIL: legacy user-facing date format remains' >&2
  exit 1
fi

echo 'PASS: standardized panel dates use dd-MM-yyyy and media timestamps use HH:mm'
