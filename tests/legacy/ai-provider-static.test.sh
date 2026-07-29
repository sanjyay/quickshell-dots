#!/usr/bin/env bash
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
theme="$repo/versions/default/Theme.qml"
service="$repo/versions/default/services/AiUsageService.qml"
fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
require() { grep -Fq -- "$1" "$2" || fail "missing '$1' in ${2#$repo/}"; }

for provider in claude codex opencode; do
  require 'OnUnitActiveSec=1min' "$repo/systemd/$provider-usage.timer"
done
for alias in aiClHas aiClFresh aiClPct5h aiClPct7d aiClBlocked aiCxHas aiCxFresh aiCxState aiCxHas5h aiCxHasWeekly aiCxPct5h aiCxPct7d aiOcHas aiOcFresh aiOcPct5h aiOcPct7d aiOcModels; do
  require "property alias $alias:" "$theme"
done
require 'onTriggered: service.refreshAiUsage(service.panelVisible, true)' "$service"
require 'if (aiUsageVisible) refreshAiUsage()' "$theme"
require 'if (skipBackendKick !== true) kickAiBackends(only)' "$service"
require 'var minGap = panelVisible ? 15000 : 60000' "$service"
require 'Date.now() / 1000 - mtime) < 900' "$service"
require '.cache/claude-usage.json' "$service"
require '.cache/codex-usage.json' "$service"
require '.cache/opencode-usage.json' "$service"
require 'function refreshAiUsage(selectedOnly, skipBackendKick)' "$theme"
if grep -Fq 'onTriggered: service.refreshAiUsage(service.panelVisible)' "$service"; then
  fail "periodic QML timer still launches AI backends"
fi
if rg -q 'id: aiRead(Claude|Codex|OpenCode)|id: aiRunBackends' "$theme"; then
  fail "Theme still owns AI cache/provider processes"
fi

printf 'ok (systemd-owned scheduled AI provider refresh)\n'
