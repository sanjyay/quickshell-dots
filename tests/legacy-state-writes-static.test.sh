#!/usr/bin/env bash
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
theme="$repo/versions/default/Theme.qml"
bar="$repo/versions/default/BarSlot.qml"
writer="$repo/versions/default/modules/AtomicStateWriter.qml"

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
require_literal() { grep -Fq -- "$1" "$2" || fail "missing '$1' in ${2#$repo/}"; }

# Keep all four legacy paths and serializers while centralizing queued writes.
for path in quickshell_widgets quickshell_splits; do require_literal "$path" "$theme"; done
for path in quickshell_barorder quickshell_barsplits; do require_literal "$path" "$bar"; done
require_literal 'splitSaveWriter.write(line + "\n")' "$theme"
require_literal 'widgetSaveWriter.write(line + "\n")' "$theme"
require_literal 'orderSaveWriter.write(serialized)' "$bar"
require_literal 'splitSaveWriter.write(serialized)' "$bar"
[[ "$(rg -o 'AtomicStateWriter[[:space:]]*\{' "$theme" "$bar" | wc -l)" -eq 4 ]] || fail "expected four legacy state writers"

# No legacy save path may return to direct shell redirection.
! rg -q '(widget|split|order)SaveProc' "$theme" "$bar" || fail "direct legacy cache writer remains"
require_literal 'signal failed(string state, int exitCode)' "$writer"
require_literal 'if (writer.pending !== writer.inFlight)' "$writer"

printf 'ok (queued atomic legacy-state write contract)\n'
