#!/usr/bin/env bash
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
service="$repo/versions/default/services/AiUsageService.qml"
theme="$repo/versions/default/Theme.qml"
widget="$repo/versions/default/modules/ClaudeWidget.qml"
panel="$repo/versions/default/panels/AiUsagePanel.qml"
runtime="$repo/runtime/Bar.qml"
rise="$repo/versions/rise/Bar.qml"

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
require() { rg -Fq -- "$1" "$2" || fail "missing '$1' in ${2#$repo/}"; }
reject() { ! rg -Fq -- "$1" "$2" || fail "obsolete '$1' remains in ${2#$repo/}"; }

require 'startupReady: theme.aiCollectorReady' "$theme"
require 'aiCollectorReady: root.initialized' "$rise"
require 'initialRefreshStarted' "$service"
require 'if (startupReady && !initialRefreshStarted)' "$service"
require 'collectorProcess.running' "$service"
require 'watchChanges: true' "$service"
require 'lastRefreshStartedAt' "$service"
require 'function isStale(name)' "$service"
require 'value.status !== "ok"' "$service"
require 'readonly property bool barHasData: isOpenCode ? ocHas : (isCodex ? cxHas : clHas)' "$widget"
reject 'readonly property bool barHasData: isCodex ? (cxHas || cxActive)' "$widget"
require 'root.aiCxMessage' "$widget"
require 'root.aiUsage' "$panel"
require 'root.forceAiUsageRefresh(false)' "$panel"
require 'function refreshAiUsage(): bool' "$runtime"
require 'function aiUsageDiagnostics(): string' "$runtime"
reject 'bash", "-lc"' "$service"
reject '.cache/codex-usage.json' "$service"
for provider in claude codex opencode; do
    [[ ! -e "$repo/systemd/$provider-usage.service" ]] || fail "legacy $provider service remains"
    [[ ! -e "$repo/systemd/$provider-usage.timer" ]] || fail "legacy $provider timer remains"
done

printf 'PASS: normalized AI usage service, shared model, and Quattro startup contracts\n'
