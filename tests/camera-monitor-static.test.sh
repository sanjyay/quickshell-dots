#!/usr/bin/env bash
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
monitor="$repo/versions/default/modules/CameraSwitchMonitor.qml"
helper="$repo/versions/default/helpers/camera-switch-monitor.py"
shell="$repo/versions/default/shell.qml"
widget="$repo/versions/default/modules/PrivacyCameraWidget.qml"

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
require_literal() { grep -Fq -- "$1" "$2" || fail "missing '$1' in ${2#$repo/}"; }

# Stable state protocol exposed to shell.qml, Theme, and every per-monitor view.
for declaration in \
  'property bool opened: false' \
  'property bool known: false' \
  'property bool stateKnown: known' \
  'property bool cameraEnabled: false' \
  'property string devicePath: ""' \
  'property string lastScanCode: ""' \
  'property int rawEvents: 0' \
  'property int keyEvents: 0' \
  'property string error: ""'; do
  require_literal "$declaration" "$monitor"
done
require_literal 'if (key === "device") devicePath = value' "$monitor"
require_literal 'else if (key === "enabled") cameraEnabled = value === "1"' "$monitor"
require_literal 'target: cameraSwitchMonitor' "$shell"
require_literal 'if (cameraSwitchMonitor.stateKnown)' "$shell"
require_literal 'cameraSwitch.cameraEnabled' "$widget"

require_literal 'Qt.resolvedUrl("../helpers/camera-switch-monitor.py")' "$monitor"
require_literal 'command: ["python3", "-u", monitor.helperPath]' "$monitor"
for literal in 'SCAN_CAMERA_DISABLED = 0x10D' 'SCAN_CAMERA_ENABLED = 0x10C' \
  'EV_MSC = 0x04' 'MSC_SCAN = 0x04' 'KEY_UNKNOWN = 240' 'elif value != 1:' \
  'self.known, self.enabled = True, False' 'self.known, self.enabled = True, True'; do
  require_literal "$literal" "$helper"
done

# Preserve discovery order, fallback, retry behavior, and permission diagnostics
# until extracted code has equivalent fixture-driven tests.
proc_line="$(grep -nF '("/proc discovery", self.proc_device)' "$helper" | cut -d: -f1)"
event_line="$(grep -nF '("event scan", self.scan_event_devices)' "$helper" | cut -d: -f1)"
by_path_line="$(grep -nF '("by-path scan", self.scan_by_path_links)' "$helper" | cut -d: -f1)"
[[ "$proc_line" -lt "$event_line" && "$event_line" -lt "$by_path_line" ]] || fail "camera discovery order changed"
require_literal 'HARDCODED_FALLBACK = "/dev/input/event16"' "$helper"
require_literal 'exc.errno == errno.EACCES' "$helper"
require_literal 'RAW type=%d code=%d value=%d' "$helper"
require_literal 'fix permissions: add the user to the input group' "$helper"

printf 'ok (camera monitor protocol characterization)\n'
