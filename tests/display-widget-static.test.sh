#!/usr/bin/env bash
set -euo pipefail

root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
theme="$root/versions/default/Theme.qml"
slot="$root/versions/default/BarSlot.qml"
widget="$root/versions/default/modules/DisplayWidget.qml"
panel="$root/versions/default/panels/DisplayPanel.qml"
service="$root/versions/default/services/DisplayService.qml"
installer="$root/install.sh"
uninstaller="$root/uninstall.sh"
runtime="$root/runtime/Bar.qml"

grep -Fq 'DisplayWidget       { root: barSlot.root; barScreen: barSlot.screen' "$slot"
grep -Fq 'anchors.fill: parent' "$widget"
grep -Fq 'widget.root.displayVisible = false' "$widget"
grep -Fq 'widget.root.activatePopupScreen(widget.barScreen)' "$widget"
grep -Fq 'widget.root.display.outputName = widget.barScreen.name' "$widget"
grep -Fq 'implicitWidth: root.modDisplay ? 24 : 0' "$widget"
grep -Fq 'color: root.seal' "$widget"
grep -Fq 'onClicked: panel.root.displayVisible = false' "$panel"
grep -Fq 'Keys.onEscapePressed' "$panel"
grep -Fq 'popupOpened("displayVisible")' "$theme"
grep -Fq 'if (except !== "displayVisible") displayVisible = false' "$theme"
grep -Fq 'readonly property bool anyPopupVisible:' "$theme"
grep -Fq '|| displayVisible' "$theme"
grep -Fq 'property bool modDisplay:    true' "$theme"
grep -Fq 'function uiFontSize(basePixels)' "$theme"
grep -Fq 'readonly property int menuFontSize: uiFontSize(18)' "$theme"
grep -Fq 'if (parts.length > wsField + 36) theme.modDisplay = parts[wsField + 36] !== "0"' "$theme"
grep -Fq 'label: "Display";     active: root.modDisplay; onActivated: root.modDisplay = !root.modDisplay' "$root/versions/default/panels/ControlPanel.qml"
grep -Fq 'font.pixelSize: root.uiFontSize(11)' "$root/versions/default/panels/ControlPanel.qml"
grep -Fq 'height: Math.max(25, root.uiFontSize(11) + 14)' "$root/versions/default/panels/ControlPanel.qml"
grep -Fq 'font.pixelSize: root.uiFontSize(12)' "$root/versions/default/modules/ClockWidget.qml"
grep -Fq 'font.pixelSize: root.uiFontSize(12)' "$root/versions/default/modules/CpuWidget.qml"
grep -Fq 'font.pixelSize: root.uiFontSize(12)' "$root/versions/default/modules/MemoryWidget.qml"
grep -Fq 'font.pixelSize: root.uiFontSize(12)' "$root/versions/default/modules/MprisWidget.qml"

grep -Fq '["hyprctl", "monitors", "-j"]' "$service"
grep -Fq 'DisplayModel.parseMonitors(raw, outputName)' "$service"
grep -Fq 'unsupportedBrightnessOutput !== outputName' "$service"
grep -Fq 'interval: 180' "$service"
grep -Fq 'pendingBrightnessPercent !== service.inFlightBrightnessPercent' "$service"
grep -Fq 'service.brightnessReadProcess.running = true' "$service"
grep -Fq 'readonly property var textSizeSteps: [10, 12, 14, 16, 18, 20]' "$service"
grep -Fq 'function onFontBaseSizeChanged()' "$service"
grep -Fq 'service.acceptSystemTextSize(Style.font.baseSize)' "$service"
grep -Fq 'textSizeProcess.command = ["omarchy-display-text-size", String(inFlightTextSize)]' "$service"
grep -Fq 'service.pendingTextSize !== service.inFlightTextSize' "$service"
grep -Fq 'readonly property var scalePresets: ["1", "1.25", "1.6", "2", "3", "4"]' "$service"
grep -Fq 'scaleApplying' "$panel"
grep -Fq 'function openDisplay(): bool' "$runtime"
grep -Fq 'function setDisplayTextSize(pixelSize: int): bool' "$runtime"

grep -Fq 'scripts/astra-display-scale' "$installer"
grep -Fq 'BEGIN QUICKSHELL-ASTRA DISPLAY SCALE' "$uninstaller"
grep -Fq 'quickshell-astra-before-display-scale.bak' "$uninstaller"

if rg -n -i 'shibumi' "$widget" "$panel" "$service" "$root/scripts/astra-display-scale"; then
  echo "Display feature must not reference Shibumi" >&2
  exit 1
fi

echo "display widget static tests passed"
