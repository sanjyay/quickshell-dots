#!/usr/bin/env bash
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
clock="$repo/versions/default/modules/ClockWidget.qml"
calendar="$repo/versions/default/panels/CalendarPopup.qml"
bar="$repo/versions/default/BarSlot.qml"
screen_record="$repo/versions/default/modules/ScreenRecordWidget.qml"
button="$repo/versions/default/modules/BarWidgetButton.qml"
pulse="$repo/versions/default/modules/Pulse.qml"
shell="$repo/versions/default/shell.qml"

require() { rg -q -- "$1" "$2" || { printf 'FAIL: missing %s in %s\n' "$1" "$2" >&2; exit 1; }; }
forbid() { ! rg -q -- "$1" "$2" || { printf 'FAIL: unexpected %s in %s\n' "$1" "$2" >&2; exit 1; }; }

# This guards the declarative input contract; compositor-level pointer testing
# remains a manual integration concern because Quickshell needs a Wayland session.
require 'BarWidgetButton' "$clock"
require 'implicitHeight: Math.max\(32, root.pillH\)' "$clock"
require 'acceptedButtons: Qt.LeftButton \| Qt.RightButton' "$clock"
require 'preventStealing: true' "$clock"
require 'onEscapePressed:' "$clock"
require 'FocusScope' "$button"
require 'anchors.fill: parent' "$button"
require 'activeFocusOnTab: enabled && visible' "$button"
require 'Qt.Key_Return' "$button"
require 'Qt.Key_Space' "$button"
require 'Qt.Key_Escape' "$button"
require 'Accessible.role: Accessible.Button' "$button"
require 'WlrLayershell.keyboardFocus: root.calendarVisible \? WlrKeyboardFocus.Exclusive' "$calendar"
require 'event.key === Qt.Key_Escape' "$calendar"
require 'implicitWidth: Math.round\(centerRow.implicitWidth\)' "$repo/versions/default/BarSlot.qml"
forbid 'id: centerClickArea' "$repo/versions/default/BarSlot.qml"
require 'z: 30' "$repo/versions/default/BarSlot.qml"
require 'readonly property int centerGap: 28' "$repo/versions/default/BarSlot.qml"
require 'readonly property real leftEdgeX:' "$bar"
require 'readonly property real rightEdgeX:' "$bar"
require 'readonly property real minCenterX:' "$bar"
require 'readonly property real maxCenterX:' "$bar"
require 'readonly property real preferredCenterX:' "$bar"
require 'readonly property real centerTargetX:' "$bar"
forbid 'narrowStage' "$bar"
forbid 'groupVisibleAtStage' "$bar"
forbid 'scheduleNarrowUpdate' "$bar"
forbid 'recordingWidth: 52' "$screen_record"
require 'implicitWidth: recording \? row.implicitWidth \+ 6 : 0' "$screen_record"
require 'visible: implicitWidth > 0.5' "$screen_record"
require 'enabled: rootMod.recording' "$screen_record"
require 'property alias inputItem: pulseButton' "$pulse"
require 'visible: island.visible && island.hint.length > 0' "$pulse"
require 'mask: Region \{ item: pulse.inputItem \}' "$shell"

# Every module-level pointer surface must use the shared in-bounds control.
if rg -q --glob '!BarWidgetButton.qml' 'MouseArea[[:space:]]*\{' "$repo/versions/default/modules"; then
    printf 'FAIL: module bypasses BarWidgetButton\n' >&2
    exit 1
fi

printf 'ok (clock input contract)\n'
