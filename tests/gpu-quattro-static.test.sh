#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

out="$(versions/default/modules/qs-gpu-probe.sh)"
jq -e '.schemaVersion == 1 and (.status == "ok" or .status == "unavailable")' <<<"$out" >/dev/null
grep -Fq 'Qt.resolvedUrl("../modules/qs-gpu-probe.sh")' versions/default/services/SystemMetricsService.qml
! grep -Rq '$HOME/.config/quickshell/bar/modules/qs-gpu-probe.sh' \
  versions/default/modules/CpuWidget.qml versions/default/panels/CpuPanel.qml versions/default/services/SystemMetricsService.qml
! grep -q 'Process {' versions/default/modules/CpuWidget.qml
! grep -q 'Process {' versions/default/panels/CpuPanel.qml
grep -Fq 'root.systemMetrics.gpuTemperatureC' versions/default/modules/CpuWidget.qml
grep -Fq 'readonly property var metricsModel: root.systemMetrics' versions/default/panels/CpuPanel.qml
grep -Fq 'gpuDisplayModelReady' versions/rise/Bar.qml
grep -Fq 'cmp -s "$repo_root/versions/default/modules/qs-gpu-probe.sh"' install.sh
printf 'PASS: GPU JSON, plugin-relative collector, shared model, health and install contracts\n'
