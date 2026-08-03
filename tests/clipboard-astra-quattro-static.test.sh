#!/usr/bin/env bash
set -euo pipefail

repo="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
panel="$repo/versions/default/panels/HistoryPanel.qml"
bar="$repo/versions/astra/Bar.qml"
installer="$repo/install.sh"

grep -Fq 'HistoryPanel { root: theme }' "$bar"
grep -Fq 'target: "quickshell-astra-clipboard"' "$bar"
grep -Fq '/.local/state/omarchy/clipboard-history.json' "$panel"
grep -Fq 'omarchy-clipboard-paste-text' "$panel"
grep -Fq 'omarchy-clipboard-paste-file' "$panel"
grep -Fq 'isSensitiveClipboardText(fullText)' "$panel"
grep -Fq 'value.toLowerCase() === currentUser' "$panel"
grep -Fq 'HistoryModel.recordingStartMs(name)' "$panel"
grep -Fq 'HistoryModel.sorted(merged)' "$panel"
grep -Fq 'historyFileMtimeMs - i * 60000' "$panel"
grep -Fq 'recording-active' "$panel"
grep -Fq 'waiting-for-final-file' "$panel"
grep -Fq 'previewRetryTimer' "$panel"
grep -Fq 'model: panel.fanItems' "$panel"
grep -Fq 'if (signature !== modelSignature)' "$panel"
grep -Fq 'panel.retryPreview(modelData)' "$panel"
grep -Fq 'function refreshRecordings()' "$panel"
grep -Fq 'id: historyFileWatcher' "$panel"
grep -Fq 'watchChanges: true' "$panel"
grep -Fq 'if (queryProc.running)' "$panel"
grep -Fq '.[0:120]' "$panel"
grep -Fq 'root.formatDisplayDateTime(startedAtMs, true)' "$panel"
grep -Fq 'id: screenshotWatchProc' "$panel"
grep -Fq 'cache: false' "$panel"
grep -Fq 'visible: modelData.kind !== "recording" && modelData.kind !== "screenshot"' "$panel"
grep -Fq 'function diagnosticsObject()' "$panel"
grep -Fq 'function openScreenRecording(entry)' "$repo/versions/default/NotificationManager.qml"
grep -Fq 'exec omacut \"$candidate\"' "$repo/versions/default/NotificationManager.qml"
grep -Fq 'hl.unbind("SUPER + CTRL + V")' "$installer"
grep -Fq 'Quickshell Astra clipboard history' "$installer"

if grep -Eqi 'elephant|qs -c bar|quickshell -c bar' "$panel" "$bar"; then
  echo "FAIL: retired clipboard backend or standalone Quickshell path found" >&2
  exit 1
fi

echo "PASS: Astra history uses the native Quattro clipboard store and binding"
