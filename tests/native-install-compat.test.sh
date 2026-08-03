#!/usr/bin/env bash
set -euo pipefail

repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
tmp=$(mktemp -d "${TMPDIR:-/tmp}/astra-native-test.XXXXXX")
trap 'rm -rf -- "$tmp"' EXIT

fail() { printf 'not ok: %s\n' "$*" >&2; exit 1; }
pass() { printf 'ok: %s\n' "$*"; }

jq -e '.id == "io.github.sanjyay.quickshell-astra" and .kinds == ["bar"] and
  .entryPoints.bar == "runtime/Bar.qml"' "$repo/manifest.json" >/dev/null
pass 'manifest contract'

fixture="$tmp/io.github.sanjyay.quickshell-astra"
mkdir -p "$fixture"
(cd "$repo" && git ls-files --cached --others --exclude-standard -z |
  tar --null -T - -cf -) | (cd "$fixture" && tar -xf -)
rm -rf -- "$fixture/node_modules"
[[ -f "$fixture/runtime/Bar.qml" && -f "$fixture/versions/astra/Bar.qml" ]]
pass 'Git payload contains the complete entry-point chain'

env -u NODE_PATH HOME="$tmp/home-missing" XDG_DATA_HOME="$tmp/data-missing" \
  node "$fixture/scripts/holiday-helper.js" dependency-status >"$tmp/missing.json"
jq -e '.ok == true and .available == false and .error.code == "dependency-unavailable"' \
  "$tmp/missing.json" >/dev/null
pass 'missing date-holidays is structured and nonfatal'

node "$repo/scripts/holiday-helper.js" dependency-status | jq -e \
  '.ok == true and .available == true and .version == "3.34.0"' >/dev/null
TZ=Asia/Kolkata XDG_CACHE_HOME="$tmp/present-cache" node "$repo/scripts/holiday-helper.js" \
  get --country IN --year 2026 --subdivision TN --show-national true --show-regional true |
  jq -e '.ok == true and any(.holidays[]; .date == "2026-01-26")' >/dev/null
pass 'present pinned holiday runtime is functional'

grep -Fq 'Component.onCompleted: refresh()' "$repo/versions/default/services/RuntimeCapabilities.qml"
[[ $(grep -c 'Component.onCompleted: refresh()' "$repo/versions/default/services/RuntimeCapabilities.qml") == 1 ]]
grep -Fq 'property int probeCount: 0' "$repo/versions/default/services/RuntimeCapabilities.qml"
grep -Fq 'if (probe.running) return false' "$repo/versions/default/services/RuntimeCapabilities.qml"
pass 'optional dependency probe is cached and controlled'

grep -Fq 'status = capabilities && capabilities.probed ? "degraded"' \
  "$repo/versions/default/services/HolidayService.qml"
grep -Fq 'Loader {' "$repo/runtime/Bar.qml"
! grep -RE '(\.local/bin/qs-|\["qs-(state-write|emoji|capture|menu-|theme-switcher|wallpaper-switcher|notification-silence))' \
  "$repo/versions" >/dev/null
! grep -RE 'ShellRoot|qs -n|qs -c bar|quickshell -c bar' "$repo/runtime" "$repo/versions" >/dev/null
pass 'one missing dependency does not gate core construction or start a second shell'

! grep -RE 'systemctl --user (enable|start)|bindings\.lua' "$repo/runtime" "$repo/versions" >/dev/null
pass 'bar construction does not write Hyprland or systemd configuration'

home="$tmp/home"
mkdir -p "$home/.config/hypr"
cat >"$home/.config/hypr/bindings.lua" <<'LUA'
local keep = "unrelated"
-- BEGIN QUICKSHELL-RISE MANAGED BLOCK
hl.unbind("SUPER + CTRL + V")
o.bind("SUPER + CTRL + V", "Quickshell Rise clipboard history", "omarchy-shell quickshell-rise-clipboard toggle")
-- END QUICKSHELL-RISE MANAGED BLOCK
LUA
before=$(sha256sum "$home/.config/hypr/bindings.lua")
HOME="$home" XDG_CONFIG_HOME="$home/.config" XDG_DATA_HOME="$home/.local/share" \
  "$repo/scripts/astra-setup-extras" --dry-run --all >/dev/null
[[ "$before" == "$(sha256sum "$home/.config/hypr/bindings.lua")" ]]
[[ ! -e "$home/.local/share/quickshell-astra/runtime" ]]
pass 'setup-extras --dry-run changes nothing'

HOME="$home" XDG_CONFIG_HOME="$home/.config" "$repo/scripts/astra-setup-extras" --bindings >/dev/null
HOME="$home" XDG_CONFIG_HOME="$home/.config" "$repo/scripts/astra-setup-extras" --bindings >/dev/null
[[ $(grep -c '^-- BEGIN QUICKSHELL-ASTRA MANAGED BLOCK$' "$home/.config/hypr/bindings.lua") == 1 ]]
! grep -Fq 'BEGIN QUICKSHELL-RISE' "$home/.config/hypr/bindings.lua"
grep -Fq 'local keep = "unrelated"' "$home/.config/hypr/bindings.lua"
pass 'managed Lua replacement is idempotent and preserves unrelated configuration'

mkdir -p "$home/.local/share/quickshell-astra/runtime" "$home/.local/share/unrelated"
printf owned >"$home/.local/share/quickshell-astra/runtime/owned"
printf keep >"$home/.local/share/unrelated/keep"
HOME="$home" XDG_CONFIG_HOME="$home/.config" XDG_DATA_HOME="$home/.local/share" \
  "$repo/scripts/astra-remove-extras" >/dev/null
[[ ! -e "$home/.local/share/quickshell-astra/runtime" ]]
[[ -f "$home/.local/share/unrelated/keep" ]]
grep -Fq 'local keep = "unrelated"' "$home/.config/hypr/bindings.lua"
! grep -Fq 'BEGIN QUICKSHELL-ASTRA' "$home/.config/hypr/bindings.lua"
pass 'remove-extras deletes only Astra-owned optional files and block'

! grep -RIl --exclude-dir=.git --exclude-dir=tests -- '/home/[[:alnum:]_.-]\+/' "$fixture" | grep -q . ||
  fail 'personal absolute path exists'
! grep -RIn --exclude=CHANGELOG.md --exclude=AGENTS.md --exclude=astra-native-check \
  --exclude=native-install-compat.test.sh \
  'https://github.com/sanjyay/quickshell-dots' "$fixture" >/dev/null ||
  fail 'stale quickshell-dots URL exists'
pass 'portable paths and current repository URL'

grep -Fq 'LEGACY_PLUGIN_ID="io.github.sanjyay.quickshell-rise"' "$repo/install.sh"
grep -Fq 'target: "quickshell-rise-health"' "$repo/runtime/Bar.qml"
pass 'documented Rise aliases and migration compatibility remain'

"$fixture/scripts/astra-native-check" "$fixture" >/dev/null
"$repo/scripts/astra-native-check" "$repo" >/dev/null
pass 'source and installed-path native checks'
