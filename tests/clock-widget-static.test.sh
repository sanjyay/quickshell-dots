#!/usr/bin/env bash
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
clock="$repo/versions/default/modules/ClockWidget.qml"
calendar="$repo/versions/default/panels/CalendarPopup.qml"
bar="$repo/versions/default/BarSlot.qml"
screen_record="$repo/versions/default/modules/ScreenRecordWidget.qml"
button="$repo/versions/default/modules/BarWidgetButton.qml"
shell="$repo/versions/default/shell.qml"

require() { rg -q -- "$1" "$2" || { printf 'FAIL: missing %s in %s\n' "$1" "$2" >&2; exit 1; }; }
forbid() { ! rg -q -- "$1" "$2" || { printf 'FAIL: unexpected %s in %s\n' "$1" "$2" >&2; exit 1; }; }
center_component="$(sed -n '/id: compCenter/,/^    Component { id: compMpris/p' "$bar")"
require_center() { rg -U -q -- "$1" <<< "$center_component" || { printf 'FAIL: missing %s in G8 center component\n' "$1" >&2; exit 1; }; }
forbid_center() { ! rg -U -q -- "$1" <<< "$center_component" || { printf 'FAIL: unexpected %s in G8 center component\n' "$1" >&2; exit 1; }; }

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
require_center 'id: compCenter[^\n]*\n[[:space:]]*Item \{'
require_center 'implicitWidth: Math.round\(clock.implicitWidth(.|\n){0,160}indicatorWrapper.width\)'
require_center 'implicitHeight: 32'
require_center 'height: 32'
require_center 'id: centerBg(.|\n){0,160}anchors.centerIn: parent(.|\n){0,120}height: barSlot.root.pillH'
require_center 'spacing: 0(.|\n){0,120}BarWidgetButton \{(.|\n){0,120}id: clockSegment'
require_center 'id: clockSegment(.|\n){0,200}width: Math.max\(0, g8.width - indicatorWrapper.width\)(.|\n){0,80}height: 32'
require_center 'ClockWidget \{(.|\n){0,180}interactive: false'
require_center 'id: indicatorWrapper(.|\n){0,120}anchors.verticalCenter: parent.verticalCenter(.|\n){0,180}height: 32'
require_center 'acceptedButtons: Qt.LeftButton \| Qt.RightButton'
require_center 'onClicked:'
require_center 'onWheel:'
forbid_center 'contentInputPriority'
forbid 'id: centerClickArea' "$bar"
require 'z: 30' "$bar"
require 'readonly property int preferredCenterGap: 28' "$bar"
require 'readonly property int minimumCenterGap: 6' "$bar"
require 'readonly property bool compactLayout: width < 2048' "$bar"
require 'compact: barSlot.compactLayout && barSlot.root.hasBattery && barSlot.root.modBattery' "$bar"
require 'NetworkWidget[[:space:]]+\{ root: barSlot.root; compact: barSlot.compactLayout;' "$bar"
require 'readonly property real freeCenterSpace:' "$bar"
require 'Math.min\(preferredCenterGap, Math.floor\(freeCenterSpace / 2\)\)' "$bar"
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
require 'implicitHeight: 32' "$screen_record"
require 'visible: implicitWidth > 0.5' "$screen_record"
require 'enabled: rootMod.recording && !rootMod.stopInFlight' "$screen_record"
require 'BarWidgetButton' "$screen_record"
require 'theme: rootMod.root' "$screen_record"
require 'traceName: "recording-timer-handler"' "$screen_record"
require 'anchors.fill: parent' "$screen_record"
require 'command: \["omarchy-capture-screenrecording", "--stop-recording"\]' "$screen_record"
require 'if \(!rootMod.recording || rootMod.stopInFlight\) return' "$screen_record"
require 'rootMod.stopInFlight = true' "$screen_record"
require 'onExited: function\(code\)' "$screen_record"
require 'else if \(!rootMod.stopInFlight\)' "$screen_record"
forbid 'bash.*--stop-recording' "$screen_record"
forbid 'contentInputPriority' "$button"
forbid 'contentInputPriority' "$bar"
require 'NotificationToastOverlay' "$shell"
require 'HardwareOsdOverlay' "$shell"

# Every module-level pointer surface must use the shared in-bounds control.
if rg -q --glob '!BarWidgetButton.qml' 'MouseArea[[:space:]]*\{' "$repo/versions/default/modules"; then
    printf 'FAIL: module bypasses BarWidgetButton\n' >&2
    exit 1
fi

printf 'ok (clock input contract)\n'
