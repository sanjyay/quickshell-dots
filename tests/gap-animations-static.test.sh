#!/usr/bin/env bash
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
theme="$repo/versions/default/Theme.qml"
panel="$repo/versions/default/panels/ControlPanel.qml"
stream="$repo/versions/default/modules/ParticleStream.qml"
bar="$repo/versions/default/BarSlot.qml"

for label in \
  "No gap animation" "Flowing sine wave" "Audio-reactive waveform" \
  "Network pulse" "Breathing glow" "Particle stream" "Comet sweep" \
  "Electric arc" "Gradient drift" "Widget energy transfer" "Idle ripple" \
  "Clock-synchronized wave" "Workspace transition trail" "Recommended combo"; do
  grep -Fq "label: \"$label\"" "$panel"
done

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
