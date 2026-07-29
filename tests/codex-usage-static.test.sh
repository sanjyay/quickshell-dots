#!/usr/bin/env bash
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

python3 "$repo/tests/ai-usage-collector.test.py"
rg -q 'windowDurationMins' "$repo/scripts/ai-usage-collector"
rg -q 'weekly remaining' "$repo/versions/default/panels/AiUsagePanel.qml"
rg -q 'Credits remaining' "$repo/versions/default/panels/AiUsagePanel.qml"

printf 'ok (Codex usage normalization)\n'
