#!/usr/bin/env bash
# Run Topgrade from the updater panel, then always republish package state.
# Topgrade owns its own interactive/privileged flow in the visible terminal.
set -uo pipefail

topgrade_bin="${QS_TOPGRADE_COMMAND:-topgrade}"
state_helper="${QS_PACKAGE_UPDATE_HELPER:-$HOME/.config/quickshell/bin/qs-package-update-state.sh}"
ipc_bin="${QS_IPC_COMMAND:-qs}"

if command -v -- "$topgrade_bin" >/dev/null 2>&1; then
    "$topgrade_bin"
    topgrade_status=$?
else
    printf 'Topgrade is not installed or is not available in PATH.\n' >&2
    topgrade_status=127
fi

# A failed update still gets a fresh state: the widget remains visible if
# packages are pending, and disappears as soon as the successful check is clean.
if [[ -x "$state_helper" ]]; then
    "$state_helper" >/dev/null || true
fi

# Tell an already-running bar to consume the freshly written state now. This is
# best effort so the user's terminal still receives Topgrade's true exit status.
if command -v -- "$ipc_bin" >/dev/null 2>&1; then
    "$ipc_bin" -c bar ipc call -- omarchy.system-update refresh >/dev/null 2>&1 || true
fi

exit "$topgrade_status"
