#!/usr/bin/env bash
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
manager="$repo/versions/default/NotificationManager.qml"
writer="$repo/versions/default/modules/AtomicStateWriter.qml"

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
require_literal() { grep -Fq -- "$1" "$2" || fail "missing '$1' in ${2#$repo/}"; }

# Preserve the cache path/schema while routing writes through one atomic helper.
require_literal 'qs-rise-notifications.json' "$manager"
require_literal 'JSON.stringify({ recent: saved })' "$manager"
require_literal 'AtomicStateWriter {' "$manager"
require_literal 'path: manager.cachePath' "$manager"
require_literal 'validateJson: true' "$manager"
require_literal '["qs-state-write", "--json", writer.path]' "$writer"
require_literal 'stdinEnabled: true' "$writer"
require_literal 'JSON.stringify({ data: writer.inFlight })' "$writer"
require_literal 'if (writer.pending !== writer.inFlight)' "$writer"
require_literal 'Qt.callLater(writer.startWrite)' "$writer"
! rg -q 'cacheFile\.setText' "$manager" || fail "notification cache still uses a direct write"

# The helper must remain synchronized across every deployment lifecycle.
for file in uninstall.sh scripts/qs-owned-artifacts.tsv docs/runtime-ownership.md; do
  require_literal 'qs-state-write' "$repo/$file"
done
require_literal 'qs_artifacts_each "$manifest" mandatory' "$repo/install.sh"
require_literal 'qs_artifacts_each "$manifest" mandatory' "$repo/scripts/qs-shell-post-update.sh"

printf 'ok (queued atomic notification-cache contract)\n'
