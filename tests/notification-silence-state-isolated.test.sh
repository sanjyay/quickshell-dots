#!/usr/bin/env bash
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
script="$repo/scripts/qs-notification-silence.sh"
real_home="${HOME:?HOME must be set}"
tmp="$(mktemp -d)"
trap 'rm -rf -- "$tmp"' EXIT

export HOME="$tmp/home"
export XDG_STATE_HOME="$tmp/state"
mkdir -p "$HOME" "$XDG_STATE_HOME"
state="$XDG_STATE_HOME/qs-rise/notifications-silenced"

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
[[ "$(realpath -m "$HOME")" != "$(realpath -m "$real_home")" ]] || fail "temporary HOME resolves to real HOME"
[[ "$state" == "$tmp"/* ]] || fail "state target escaped fixture"

[[ "$(bash "$script" status)" == "OFF" ]] || fail "missing state must default to OFF"
bash "$script" on
[[ "$(cat "$state")" == 1 ]] || fail "on did not persist 1"
[[ "$(stat -c %a "$state")" == 600 ]] || fail "state is not private"
[[ "$(bash "$script" status)" == "ON" ]] || fail "on status mismatch"

bash "$script" toggle
[[ "$(cat "$state")" == 0 ]] || fail "toggle from ON did not persist 0"
bash "$script" toggle
[[ "$(cat "$state")" == 1 ]] || fail "toggle from OFF did not persist 1"
bash "$script" off
[[ "$(bash "$script" status)" == "OFF" ]] || fail "off status mismatch"

if bash "$script" invalid >"$tmp/invalid.out" 2>"$tmp/invalid.err"; then
  fail "invalid command succeeded"
fi
grep -Fq 'usage: qs-notification-silence' "$tmp/invalid.err" || fail "invalid command omitted usage"

# A failed final rename must preserve the prior complete state and clean temp files.
mkdir -p "$tmp/bin"
cat > "$tmp/bin/mv" <<'SHIM'
#!/usr/bin/env bash
exit 73
SHIM
chmod +x "$tmp/bin/mv"
if PATH="$tmp/bin:/usr/bin:/bin" bash "$script" on; then
  fail "write succeeded despite failed atomic rename"
fi
[[ "$(cat "$state")" == 0 ]] || fail "failed rename corrupted prior state"
if find "$(dirname "$state")" -maxdepth 1 -name '.notifications-silenced.*' -print -quit | grep -q .; then
  fail "failed write left a temporary state file"
fi

printf 'ok (isolated atomic notification-silence state)\n'
