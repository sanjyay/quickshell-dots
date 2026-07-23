#!/usr/bin/env bash
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
theme="$repo/versions/default/Theme.qml"
service="$repo/versions/default/services/SystemStatusService.qml"
widget="$repo/versions/default/modules/ScreenRecordWidget.qml"

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
require_literal() { grep -Fq -- "$1" "$2" || fail "missing '$1' in ${2#$repo/}"; }

if grep -Fq 'property alias screenRecording: systemStatus.screenRecording' "$theme"; then
  require_literal 'property alias screenRecordingElapsed: systemStatus.screenRecordingElapsed' "$theme"
  require_literal 'property alias screenRecordingStopInFlight: systemStatus.screenRecordingStopInFlight' "$theme"
  require_literal "pgrep -f '^gpu-screen-recorder'" "$service"
  require_literal 'command: ["omarchy-capture-screenrecording", "--stop-recording"]' "$service"
  require_literal 'interval: service.screenRecording ? 1000 : 2000' "$service"
  require_literal 'readonly property bool recording: root.screenRecording' "$widget"
  require_literal 'readonly property int elapsed: root.screenRecordingElapsed' "$widget"
  require_literal 'root.stopScreenRecording()' "$widget"
  ! rg -q '^[[:space:]]*(Process|Timer)[[:space:]]*\{' "$widget" || fail "recording widget still owns processes"
else
  # Pre-migration characterization branch freezes the existing state machine.
  require_literal 'property bool recording: false' "$widget"
  require_literal 'property bool stopInFlight: false' "$widget"
  require_literal 'property int  elapsed:   0' "$widget"
  require_literal "pgrep -f '^gpu-screen-recorder'" "$widget"
  require_literal 'interval: rootMod.recording ? 1000 : 2000' "$widget"
  require_literal 'command: ["omarchy-capture-screenrecording", "--stop-recording"]' "$widget"
  require_literal 'if (code === 0)' "$widget"
  require_literal 'if (!rootMod.recording || rootMod.stopInFlight) return' "$widget"
fi

printf 'ok (screen-recording state-machine contract)\n'
