#!/usr/bin/env bash
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
theme="$repo/versions/default/Theme.qml"
service="$repo/versions/default/services/SystemMetricsService.qml"
widget="$repo/versions/default/modules/CpuWidget.qml"
panel="$repo/versions/default/panels/CpuPanel.qml"

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
require_literal() { grep -Fq -- "$1" "$2" || fail "missing '$1' in ${2#$repo/}"; }

for alias in cpuPercent cpuTemperature cpuHistory gpuDriver gpuUtilization gpuTemperature gpuMemoryUsed gpuMemoryTotal gpuMemoryAvailable gpuHistory ramPercent ramUsedGiB ramTotalGiB; do
  require_literal "property alias $alias:" "$theme"
done

require_literal '< /proc/stat' "$service"
require_literal '/proc/meminfo' "$service"
require_literal 'qs-gpu-probe.sh' "$service"
require_literal 'interval: service.panelVisible ? 1500 : 2000' "$service"
require_literal 'running: service.enabled || service.panelVisible' "$service"
require_literal 'service.cpuHistory = service.pushSample' "$service"
require_literal 'service.gpuHistory = service.pushSample' "$service"
[[ "$(rg -l '< /proc/stat' "$repo/versions/default" --glob '*.qml' | wc -l)" -eq 1 ]] || fail "CPU sampling has multiple owners"

require_literal 'readonly property int percent: root.cpuPercent' "$widget"
require_literal 'readonly property int cpuTemp: root.cpuTemperature' "$widget"
require_literal 'readonly property int gpuTemp: root.gpuTemperature' "$widget"
! rg -q '< /proc/stat|qs-gpu-probe|^[[:space:]]*Timer[[:space:]]*\{' "$widget" || fail "CPU widget still owns sampling"

require_literal 'readonly property int cpuPct: root.cpuPercent' "$panel"
require_literal 'readonly property int gpuUtil: root.gpuUtilization' "$panel"
require_literal 'readonly property int ramPct: root.ramPercent' "$panel"
require_literal "omarchy-launch-floating-terminal-with-presentation 'btop'" "$panel"
! rg -q '< /proc/stat|qs-gpu-probe|id: dataProc|^[[:space:]]*Timer[[:space:]]*\{' "$panel" || fail "CPU panel still owns sampling"

printf 'ok (singleton CPU/GPU/RAM metrics provider contract)\n'
