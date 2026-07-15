#!/usr/bin/env bash
set -euo pipefail

STATE="${XDG_STATE_HOME:-$HOME/.local/state}/qs-rise/notifications-silenced"
mkdir -p "$(dirname "$STATE")"

case "${1:-status}" in
  on) printf '1\n' > "$STATE" ;;
  off) printf '0\n' > "$STATE" ;;
  toggle) if [[ "$(cat "$STATE" 2>/dev/null || printf 0)" == 1 ]]; then printf '0\n' > "$STATE"; else printf '1\n' > "$STATE"; fi ;;
  status) [[ "$(cat "$STATE" 2>/dev/null || printf 0)" == 1 ]] && printf 'ON\n' || printf 'OFF\n' ;;
  *) printf 'usage: qs-notification-silence {on|off|toggle|status}\n' >&2; exit 2 ;;
esac
