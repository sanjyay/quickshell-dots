#!/usr/bin/env bash
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

python3 "$repo/tests/codex-usage-normalization.test.py"
rg -q 'windowDurationMins' "$repo/scripts/codex-usage"
rg -q 'weekly remaining' "$repo/versions/default/panels/AiUsagePanel.qml"
rg -q 'Credits remaining' "$repo/versions/default/panels/AiUsagePanel.qml"

printf 'ok (Codex usage normalization)\n'
