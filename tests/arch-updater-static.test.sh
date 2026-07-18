#!/usr/bin/env bash
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
widget="$repo/versions/default/modules/ArchUpdaterWidget.qml"
helper="$repo/scripts/qs-package-update-state.sh"

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
require() { rg -q -- "$1" "$2" || fail "missing $1 in $2"; }
forbid() { ! rg -q -- "$1" "$2" || fail "unexpected $1 in $2"; }

# The collector must remain active on the selected day even when Status is off.
require 'running: root\.isArchUpdateScheduleDay \|\| root\.archUpdateScheduleActive \|\| root\.archVisible' "$widget"
forbid 'root\.modStatus && \(root\.isArchUpdateScheduleDay' "$widget"

# Package updates need an actual compact bar affordance, not an invisible provider.
require 'showToday: root\.isArchUpdateScheduleDay' "$widget"
require 'implicitWidth: rootMod\.showToday \? 26 : 0' "$widget"
require 'text: rootMod\.badgeCount > 99 \? "99\+" : String\(rootMod\.badgeCount\)' "$widget"
require 'root\.archVisible = true' "$widget"
require 'root\.archUpdateScheduleActive' "$widget"
require '"--scheduled", root\.currentDateKey' "$widget"

# Delivery acknowledgement happens after QML has received the notification key.
require '--ack-notification' "$widget"
require '--ack-notification' "$helper"
require 'notification_delivery_version=2' "$helper"
require 'if \[\[ "\$active" == 1 && "\$fingerprint" != "\$notified_fingerprint" \]\]; then' "$helper"
forbid 'notified_fingerprint="\$fingerprint"' "$helper"
require 'schedule_active' "$helper"
require '\[\[ \$rc -eq 0 \|\| \$rc -eq 1 \]\]' "$helper"

printf 'ok\n'
