#!/usr/bin/env bash
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
theme="$repo/versions/default/Theme.qml"
panel="$repo/versions/default/panels/ControlPanel.qml"
stream="$repo/versions/default/modules/ParticleStream.qml"
bar="$repo/versions/default/BarSlot.qml"

for mode in 0 20 21 22 23 24 25 26 27 28 29 30 31 32; do
  grep -Fq "mode: $mode" "$panel"
done

# The selector stays compact: four buttons each cycle through an assigned group,
# immediately updating both the active label and the rendered bar animation.
grep -Fq 'columns: 2' "$panel"
grep -Fq 'model: animRow.groups' "$panel"
for group in Waves Energy Particles Ambient; do
  grep -Fq "label: \"$group\", options:" "$panel"
done
! grep -Fq 'Try look' "$panel"
grep -Fq 'var next = (animTile.selectedIndex + 1) % animTile.modelData.options.length' "$panel"
grep -Fq 'root.barAnim = animTile.modelData.options[next].mode' "$panel"

# One persisted selector controls the one existing renderer; off stops its timer.
grep -Fq 'property int barAnim: 0' "$theme"
grep -Fq 'mode:   barSlot.root.barAnim' "$bar"
[[ "$(grep -c 'ParticleStream {' "$bar")" -eq 1 ]]
grep -Fq 'root.mode !== 0' "$stream"
grep -Fq 'readonly property bool namedMode: mode >= 20 && mode <= 32' "$stream"

# Recommended mode composes shared canvas helpers, and audio capture is gated.
grep -Fq 'root.mode === 32' "$stream"
grep -Fq 'glowLine(nx1, nx2' "$stream"
grep -Fq 'linePath(nx1, nx2' "$stream"
grep -Fq 'running: root.active && root.wantsAudio' "$stream"

echo "gap animation static checks passed"
