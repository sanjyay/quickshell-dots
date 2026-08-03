#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

widget=versions/default/modules/IdleWidget.qml
all_runtime=(versions/default versions/astra runtime)

grep -Fq 'readonly property bool awake: idleService ? idleService.stayAwake === true : false' "$widget"
[[ "$(grep -Fc 'setIdleEnabled(rootMod.awake)' "$widget")" == 1 ]]
grep -Fq 'onClicked:' "$widget"
! rg -q 'onCheckedChanged|onActiveChanged|onStayAwakeChanged|onEnabledChanged|Timer|Process|omarchy-toggle-idle|pgrep -x hypridle' "$widget"
! rg -q 'IdleInhibitor[[:space:]]*[{]' "${all_runtime[@]}"
! rg -q 'function (toggleIdle|enableIdle|disableIdle|idleStatus)|toggleIdleInhibitor|setIdleInhibited' versions/astra runtime versions/default/Theme.qml
! rg -q 'SUPER \\+ CTRL \\+ I|Toggle idle inhibitor' install.sh
! rg -q 'quickshell-astra-idle-toggle' versions runtime
! rg -q 'omarchy-toggle-idle|pgrep -x hypridle|toggleIdleState|idleStateToggleProc' versions/default
grep -Fq 'firstPartyServiceFor("omarchy.idle")' versions/default/Theme.qml
grep -Fq 'observerInstances: theme.idleWidgetInstances' versions/astra/Bar.qml
grep -Fq 'quickshell-astra-owned-idle-toggle' uninstall.sh
printf 'PASS: native idle is one-way, click-only, and has no Astra binding or IPC writer\n'
