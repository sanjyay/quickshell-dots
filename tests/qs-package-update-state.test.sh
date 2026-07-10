#!/usr/bin/env bash
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
helper="$repo/scripts/qs-package-update-state.sh"
tmp="$(mktemp -d)"
trap 'rm -rf -- "$tmp"' EXIT

pass=0
fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
expect() { [[ "$1" == *"$2"* ]] || fail "expected $2 in: $1"; pass=$((pass + 1)); }
run() {
    HOME="$tmp/home" XDG_STATE_HOME="$tmp/state" QS_UPDATE_TEST_MODE=1 \
        QS_UPDATE_SYSTEM_FIXTURE="$1" QS_UPDATE_AUR_FIXTURE="${2:-}" \
        QS_REBOOT_REQUIRED_FIXTURE="${3:-0}" QS_SNAPPER_TEST_MODE="${4:-unavailable}" \
        bash "$helper"
}

mkdir -p "$tmp/home" "$tmp/fixtures"
printf 'linux 6.9 -> 6.10\n' > "$tmp/fixtures/one"
printf 'linux 6.9 -> 6.10\nmesa 24.1 -> 24.2\n' > "$tmp/fixtures/two"
: > "$tmp/fixtures/empty"
printf 'bad;name 1 -> 2\n' > "$tmp/fixtures/injected"

first="$(run "$tmp/fixtures/one")"
expect "$first" 'META|pending|'
expect "$first" '|1|1|0|1|'
expect "$first" 'U|S|linux|6.9|6.10'
first_key="$(printf '%s\n' "$first" | sed -n 's/^META|[^|]*|[^|]*|[^|]*|[^|]*|[^|]*|[^|]*|[^|]*|\([^|]*\).*/\1/p')"
[[ -n "$first_key" ]] || fail 'first pending state did not emit a notification key'

duplicate="$(run "$tmp/fixtures/one")"
expect "$duplicate" 'META|pending|'
duplicate_key="$(printf '%s\n' "$duplicate" | sed -n 's/^META|[^|]*|[^|]*|[^|]*|[^|]*|[^|]*|[^|]*|[^|]*|\([^|]*\).*/\1/p')"
[[ -z "$duplicate_key" ]] || fail 'unchanged package state emitted a duplicate notification key'

completed="$(run "$tmp/fixtures/empty")"
expect "$completed" 'META|completed|'
second_clean="$(run "$tmp/fixtures/empty")"
expect "$second_clean" 'META|clean|'

new_updates="$(run "$tmp/fixtures/two")"
expect "$new_updates" 'META|pending|'
expect "$new_updates" '|2|2|0|1|'
new_key="$(printf '%s\n' "$new_updates" | sed -n 's/^META|[^|]*|[^|]*|[^|]*|[^|]*|[^|]*|[^|]*|[^|]*|\([^|]*\).*/\1/p')"
[[ -n "$new_key" && "$new_key" != "$first_key" ]] || fail 'new package state did not produce a distinct notification key'

partial="$(run "$tmp/fixtures/one")"
expect "$partial" 'META|partial|'

reboot="$(run "$tmp/fixtures/empty" '' 1)"
expect "$reboot" 'META|reboot-required|'

denied="$(run "$tmp/fixtures/empty" '' 0 denied)"
expect "$denied" '|access-denied'
malformed="$(run "$tmp/fixtures/empty" '' 0 malformed)"
expect "$malformed" '|malformed'
timeout="$(run "$tmp/fixtures/empty" '' 0 delayed)"
expect "$timeout" '|timeout'

set +e
failed="$(HOME="$tmp/home" XDG_STATE_HOME="$tmp/state" QS_UPDATE_TEST_MODE=1 QS_UPDATE_FORCE_FAIL=1 bash "$helper")"
set -e
expect "$failed" 'META|failed|'
injected="$(run "$tmp/fixtures/injected")"
expect "$injected" 'META|failed|'

if command -v flock >/dev/null 2>&1; then
    state_dir="$tmp/state/quickshell"
    mkdir -p "$state_dir"
    : > "$state_dir/package-update-state.lock"
    flock "$state_dir/package-update-state.lock" bash -c 'sleep 1' &
    lock_pid=$!
    sleep 0.1
    busy="$(run "$tmp/fixtures/one")"
    wait "$lock_pid"
    expect "$busy" 'META|busy|'
fi

privilege_pattern='su''do|pk''exec|do''as'
if rg -n -i "\\b(${privilege_pattern})\\b" "$repo" --glob '!*.git/**'; then
    fail 'privilege-escalation command found in the repository'
fi

printf 'ok (%s assertions)\n' "$pass"
