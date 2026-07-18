#!/usr/bin/env bash
# Read-only package-update state collector for the Quickshell bar.
#
# It never elevates privileges or changes package-manager/Snapper state. Pending
# package identities are the authority for notification suppression; Snapper is
# deliberately limited to an optional access/evidence signal.
set -uo pipefail

umask 077

state_home="${XDG_STATE_HOME:-${HOME:-}/.local/state}"
if [[ -z "$state_home" || -z "${HOME:-}" ]]; then
    printf 'META|failed||||0|0|0||0|unavailable\n'
    exit 0
fi

state_dir="$state_home/quickshell"
state_file="$state_dir/package-update-state"
lock_file="$state_dir/package-update-state.lock"
mkdir -p -m 700 -- "$state_dir" 2>/dev/null || {
    printf 'META|failed||||0|0|0||0|unavailable\n'
    exit 0
}

previous_status="unknown"
previous_fingerprint=""
previous_count=0
completed_fingerprint=""
notified_fingerprint=""
settled_schedule_key=""
notification_delivery_version=""
schedule_active=0
active_schedule_key=""

load_state() {
    [[ -f "$state_file" && ! -L "$state_file" && -O "$state_file" ]] || return 0
    local key value
    while IFS='=' read -r key value; do
        case "$key" in
            status) previous_status="$value" ;;
            pending_fingerprint) previous_fingerprint="$value" ;;
            pending_count) [[ "$value" =~ ^[0-9]+$ ]] && previous_count="$value" ;;
            completed_fingerprint) completed_fingerprint="$value" ;;
            notified_fingerprint) notified_fingerprint="$value" ;;
            settled_schedule_key) settled_schedule_key="$value" ;;
            notification_delivery_version) notification_delivery_version="$value" ;;
            schedule_active) [[ "$value" == "1" ]] && schedule_active=1 ;;
            active_schedule_key) [[ "$value" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] && active_schedule_key="$value" ;;
        esac
    done < "$state_file"
}

emit_meta() {
    # status|fingerprint|completed fingerprint|count|system|aur|active|notification key|reboot|snapper
    printf 'META|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s\n' \
        "$1" "$2" "$3" "$4" "$5" "$6" "$7" "$8" "$9" "${10}"
}

save_state() {
    local status="$1" fingerprint="$2" count="$3" settled="$4" tmp
    tmp="$(mktemp -p "$state_dir" .package-update-state.XXXXXX)" || return 1
    chmod 600 -- "$tmp" || { rm -f -- "$tmp"; return 1; }
    {
        printf 'status=%s\n' "$status"
        printf 'pending_fingerprint=%s\n' "$fingerprint"
        printf 'pending_count=%s\n' "$count"
        printf 'completed_fingerprint=%s\n' "$completed_fingerprint"
        printf 'notified_fingerprint=%s\n' "$notified_fingerprint"
        printf 'settled_schedule_key=%s\n' "$settled"
        printf 'schedule_active=%s\n' "$schedule_active"
        printf 'active_schedule_key=%s\n' "$active_schedule_key"
        printf 'notification_delivery_version=2\n'
    } > "$tmp" && mv -f -- "$tmp" "$state_file" || { rm -f -- "$tmp"; return 1; }
}

load_state

# Concurrent QML instances can occur during output changes. Do not launch a
# second package-manager query; return the durable state instead.
if ! command -v flock >/dev/null 2>&1 || [[ -L "$lock_file" ]]; then
    emit_meta failed "$previous_fingerprint" "$completed_fingerprint" "$previous_count" 0 0 1 "" 0 unavailable
    exit 0
fi
exec 9>"$lock_file"
if ! flock -n 9; then
    emit_meta busy "$previous_fingerprint" "$completed_fingerprint" "$previous_count" 0 0 1 "" 0 unavailable
    exit 0
fi

# A notification is suppressed only after Quickshell has accepted it. Older
# state files marked a fingerprint as notified while merely *emitting* it; the
# version marker deliberately retries that one notification after upgrading.
if [[ "$notification_delivery_version" != "2" ]]; then
    notified_fingerprint=""
fi

scheduled_key=""
if [[ "${1:-}" == "--ack-notification" ]]; then
    fingerprint_to_ack="${2:-}"
    if [[ $# -ne 2 || ! "$fingerprint_to_ack" =~ ^[A-Za-z0-9-]{1,128}$ ]]; then
        exit 64
    fi
    if [[ "$previous_fingerprint" == "$fingerprint_to_ack" && "$previous_count" -gt 0 ]]; then
        notified_fingerprint="$fingerprint_to_ack"
        save_state "$previous_status" "$previous_fingerprint" "$previous_count" "$settled_schedule_key" || exit 1
    fi
    exit 0
elif [[ "${1:-}" == "--scheduled" ]]; then
    if [[ $# -ne 2 || ! "${2:-}" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
        exit 64
    fi
    scheduled_key="$2"
elif [[ $# -ne 0 ]]; then
    exit 64
fi

valid_package() { [[ "$1" =~ ^[A-Za-z0-9@._+:-]+$ ]]; }
valid_version() { [[ -n "$1" && "$1" != *'|'* && "$1" != *$'\n'* && ${#1} -le 512 ]]; }

system_lines=()
aur_lines=()
system_count=0
aur_count=0
collector_failed=0

# A package manager should never be allowed to fill the UI collector's memory.
# 512 blocks is a 256 KiB hard cap; timeout provides the wall-clock bound.
run_bounded() {
    (ulimit -f 512; timeout "$@")
}

parse_updates() {
    local source="$1" input="$2" name old arrow new extra
    while IFS= read -r line || [[ -n "$line" ]]; do
        [[ -z "$line" ]] && continue
        IFS=' ' read -r name old arrow new extra <<< "$line"
        if [[ "$arrow" != '->' || -n "$extra" ]] || ! valid_package "$name" || ! valid_version "$old" || ! valid_version "$new"; then
            collector_failed=1
            continue
        fi
        if [[ "$source" == S ]]; then
            system_lines+=("S|$name|$old|$new")
            ((system_count += 1))
        else
            aur_lines+=("A|$name|$old|$new")
            ((aur_count += 1))
        fi
    done <<< "$input"
}

run_collector() {
    local source="$1" output rc=0
    if [[ "${QS_UPDATE_TEST_MODE:-}" == 1 ]]; then
        local fixture="${2:-}"
        if [[ -n "$fixture" && -f "$fixture" && ! -L "$fixture" && -O "$fixture" ]]; then
            output="$(head -c 262144 -- "$fixture")"
        elif [[ -n "$fixture" ]]; then
            collector_failed=1
            return
        else
            output=""
        fi
    elif ! command -v timeout >/dev/null 2>&1; then
        collector_failed=1
        return
    elif [[ "$source" == S ]]; then
        if command -v checkupdates >/dev/null 2>&1; then
            output="$(LC_ALL=C run_bounded 45 checkupdates 2>&1)"; rc=$?
            [[ $rc -eq 0 || $rc -eq 2 ]] || collector_failed=1
        elif command -v pacman >/dev/null 2>&1; then
            output="$(LC_ALL=C run_bounded 30 pacman -Qu 2>&1)"; rc=$?
            [[ $rc -eq 0 ]] || collector_failed=1
        else
            collector_failed=1
        fi
    elif command -v paru >/dev/null 2>&1; then
        output="$(LC_ALL=C run_bounded 30 paru -Qum 2>&1)"; rc=$?
        # paru/yay use 1 for the normal "no foreign packages are pending"
        # result. Only other exits mean the collector was unable to check.
        [[ $rc -eq 0 || $rc -eq 1 ]] || collector_failed=1
    elif command -v yay >/dev/null 2>&1; then
        output="$(LC_ALL=C run_bounded 30 yay -Qum 2>&1)"; rc=$?
        [[ $rc -eq 0 || $rc -eq 1 ]] || collector_failed=1
    else
        output=""
    fi
    parse_updates "$source" "$output"
}

run_collector S "${QS_UPDATE_SYSTEM_FIXTURE:-}"
run_collector A "${QS_UPDATE_AUR_FIXTURE:-}"
[[ "${QS_UPDATE_FORCE_FAIL:-}" == 1 ]] && collector_failed=1

reboot_required=0
if [[ "${QS_UPDATE_TEST_MODE:-}" == 1 && "${QS_REBOOT_REQUIRED_FIXTURE:-}" == 1 ]] \
    || [[ -e /run/reboot-required || -e /var/run/reboot-required ]]; then
    reboot_required=1
fi

snapper_status="unavailable"
snapper_probe() {
    local output rc=0
    if [[ "${QS_UPDATE_TEST_MODE:-}" == 1 ]]; then
        case "${QS_SNAPPER_TEST_MODE:-unavailable}" in
            unavailable) snapper_status="unavailable" ;;
            denied) snapper_status="access-denied" ;;
            malformed) snapper_status="malformed" ;;
            empty) snapper_status="empty" ;;
            delayed) snapper_status="timeout" ;;
            ok) snapper_status="ok" ;;
            *) snapper_status="malformed" ;;
        esac
        return
    fi
    command -v snapper >/dev/null 2>&1 || return
    command -v timeout >/dev/null 2>&1 || { snapper_status="unavailable"; return; }
    output="$(run_bounded 6 snapper --csvout list 2>&1)"; rc=$?
    if [[ $rc -eq 124 ]]; then snapper_status="timeout"; return; fi
    if [[ $rc -ne 0 ]]; then
        if [[ "$output" =~ [Pp]ermission|[Aa]ccess|[Aa]uthori ]]; then snapper_status="access-denied"; else snapper_status="error"; fi
        return
    fi
    [[ -n "$output" ]] || { snapper_status="empty"; return; }
    [[ "$output" == *'|'* ]] && snapper_status="ok" || snapper_status="malformed"
}
snapper_probe

if [[ $collector_failed -ne 0 ]]; then
    emit_meta failed "$previous_fingerprint" "$completed_fingerprint" "$previous_count" "$system_count" "$aur_count" "$schedule_active" "" "$reboot_required" "$snapper_status"
    save_state failed "$previous_fingerprint" "$previous_count" "$settled_schedule_key" || true
    exit 0
fi

all_lines=("${system_lines[@]}" "${aur_lines[@]}")
count=$((system_count + aur_count))
fingerprint=""
if (( count > 0 )); then
    if command -v sha256sum >/dev/null 2>&1; then
        fingerprint="$(printf '%s\n' "${all_lines[@]}" | LC_ALL=C sort | sha256sum | awk '{print $1}')"
    elif command -v cksum >/dev/null 2>&1; then
        fingerprint="$(printf '%s\n' "${all_lines[@]}" | LC_ALL=C sort | cksum | awk '{print $1 "-" $2}')"
    else
        collector_failed=1
    fi
fi

if [[ $collector_failed -ne 0 || -z "$fingerprint" && $count -gt 0 ]]; then
    emit_meta failed "$previous_fingerprint" "$completed_fingerprint" "$previous_count" "$system_count" "$aur_count" "$schedule_active" "" "$reboot_required" "$snapper_status"
    save_state failed "$previous_fingerprint" "$previous_count" "$settled_schedule_key" || true
    exit 0
fi

status="clean"
active=0
notification_key=""
if (( count > 0 )); then
    status="pending"
    if [[ -n "$previous_fingerprint" && "$previous_fingerprint" != "$fingerprint" && "$count" -lt "$previous_count" ]]; then
        status="partial"
    fi
    # Only a scheduled run starts a package-reminder cycle. A manual panel
    # refresh must never make the compact widget reappear on an unrelated day.
    if [[ -n "$scheduled_key" ]]; then
        schedule_active=1
        active_schedule_key="$scheduled_key"
    fi
    active="$schedule_active"
    if [[ "$active" == 1 && "$fingerprint" != "$notified_fingerprint" ]]; then
        notification_key="$fingerprint"
    fi
    settled_schedule_key=""
elif (( reboot_required )); then
    status="reboot-required"
    if [[ -n "$scheduled_key" ]]; then
        schedule_active=1
        active_schedule_key="$scheduled_key"
    fi
    active="$schedule_active"
    settled_schedule_key=""
else
    if [[ -n "$previous_fingerprint" ]]; then
        status="completed"
        completed_fingerprint="$previous_fingerprint"
    fi
    # A successful post-update check completes the active cycle immediately;
    # it does not wait for the next bar polling interval or a Quickshell reload.
    if [[ "$schedule_active" == 1 || -n "$scheduled_key" ]]; then
        schedule_active=0
        active_schedule_key=""
        settled_schedule_key="${scheduled_key:-$(date +%F)}"
    fi
fi

save_state "$status" "$fingerprint" "$count" "$settled_schedule_key" || true
emit_meta "$status" "$fingerprint" "$completed_fingerprint" "$count" "$system_count" "$aur_count" "$active" "$notification_key" "$reboot_required" "$snapper_status"
for line in "${system_lines[@]}" "${aur_lines[@]}"; do
    [[ -n "$line" ]] && printf 'U|%s\n' "$line"
done
