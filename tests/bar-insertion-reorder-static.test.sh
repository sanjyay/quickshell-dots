#!/usr/bin/env bash
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
bar="$repo/versions/default/BarSlot.qml"

require() { rg -q -- "$1" "$bar" || { printf 'FAIL: missing %s in %s\n' "$1" "$bar" >&2; exit 1; }; }
forbid() { ! rg -q -- "$1" "$bar" || { printf 'FAIL: unexpected %s in %s\n' "$1" "$bar" >&2; exit 1; }; }

# Drops select a boundary and perform remove/insert on the combined ordering.
require 'function insertionAt\(wx, wy\)' 
require 'wx < p.x \+ it.width / 2 \? k : k \+ 1|wx < p.x \+ it.width / 2'
require 'var moved = ordered.splice\(sourceIndex, 1\)\[0\]'
require 'ordered.splice\(targetIndex, 0, moved\)'
require 'applyTo\(leftModel, ordered.slice\(0, leftCount\)\)'
require 'width: 3'

# The previous replacement/swap implementation must not return.
forbid 'var sg = srcModel.get\(srcIndex\).gid, tg = dropModel.get\(dropIndex\).gid'
forbid 'dropModel.setProperty\(dropIndex, "gid", sg\)'

printf 'ok (bar insertion reorder contract)\n'
