#!/usr/bin/env bash
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
runner="$repo/scripts/qs-topgrade-update.sh"
tmp="$(mktemp -d)"
trap 'rm -rf -- "$tmp"' EXIT

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
expect_file() { rg -q -- "$1" "$2" || fail "missing $1 in $2"; }

mkdir -p "$tmp/bin"
cat > "$tmp/bin/topgrade-ok" <<'EOF'
#!/usr/bin/env bash
printf 'topgrade\n' >> "$QS_TOPGRADE_TEST_LOG"
EOF
cat > "$tmp/bin/topgrade-fail" <<'EOF'
#!/usr/bin/env bash
printf 'topgrade-fail\n' >> "$QS_TOPGRADE_TEST_LOG"
exit 42
EOF
cat > "$tmp/helper" <<'EOF'
#!/usr/bin/env bash
printf 'refresh\n' >> "$QS_TOPGRADE_TEST_LOG"
EOF
cat > "$tmp/bin/qs" <<'EOF'
#!/usr/bin/env bash
printf 'ipc:%s\n' "$*" >> "$QS_TOPGRADE_TEST_LOG"
EOF
chmod +x "$tmp/bin"/* "$tmp/helper"

log="$tmp/log"
QS_TOPGRADE_TEST_LOG="$log" QS_TOPGRADE_COMMAND="$tmp/bin/topgrade-ok" \
    QS_PACKAGE_UPDATE_HELPER="$tmp/helper" QS_IPC_COMMAND="$tmp/bin/qs" \
    bash "$runner"
expect_file '^topgrade$' "$log"
expect_file '^refresh$' "$log"
expect_file 'ipc:-c bar ipc call -- omarchy.system-update refresh' "$log"

set +e
QS_TOPGRADE_TEST_LOG="$log" QS_TOPGRADE_COMMAND="$tmp/bin/topgrade-fail" \
    QS_PACKAGE_UPDATE_HELPER="$tmp/helper" QS_IPC_COMMAND="$tmp/bin/qs" \
    bash "$runner"
status=$?
set -e
[[ $status -eq 42 ]] || fail "Topgrade failure exit was not preserved: $status"
[[ "$(rg -c '^refresh$' "$log")" -eq 2 ]] || fail 'failed Topgrade did not refresh state'

set +e
QS_TOPGRADE_TEST_LOG="$log" QS_TOPGRADE_COMMAND="missing-topgrade" \
    QS_PACKAGE_UPDATE_HELPER="$tmp/helper" QS_IPC_COMMAND="$tmp/bin/qs" \
    bash "$runner" >/dev/null 2>&1
status=$?
set -e
[[ $status -eq 127 ]] || fail "missing Topgrade did not return 127: $status"
[[ "$(rg -c '^refresh$' "$log")" -eq 3 ]] || fail 'missing Topgrade did not refresh state'

printf 'ok\n'
