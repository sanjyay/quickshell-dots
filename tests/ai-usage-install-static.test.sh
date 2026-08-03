#!/usr/bin/env bash
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
install="$repo/install.sh"
uninstall="$repo/uninstall.sh"

rg -Fq '[[ -x "$stage/scripts/ai-usage-collector" ]]' "$install"
rg -Fq '"$TARGET/scripts/ai-usage-collector"' "$install"
rg -Fq 'cmp -s "$repo_root/scripts/ai-usage-collector" "$TARGET/scripts/ai-usage-collector"' "$install"
rg -Fq 'for legacy_ai_unit in claude-usage codex-usage opencode-usage' "$install"
rg -Fq 'for unit in claude-usage codex-usage opencode-usage' "$uninstall"
rg -Fq '"$state_dir/ai-usage.json"' "$uninstall"
! rg -Fq 'rm -rf -- "$STATE_HOME"' "$uninstall"

printf 'PASS: AI collector install, legacy cleanup, checksum, and uninstall ownership contracts\n'
