#!/usr/bin/env bash
set -euo pipefail

root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
fixture="$(mktemp -d "${TMPDIR:-/tmp}/astra-display-test.XXXXXX")"
trap 'rm -rf -- "$fixture"' EXIT
mkdir -p "$fixture/bin" "$fixture/home/.config/hypr"

cat >"$fixture/home/.config/hypr/monitors.lua" <<'LUA'
-- user comment must survive
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 })
LUA
cat >"$fixture/monitors.json" <<'JSON'
[
  {"name":"eDP-1","width":1920,"height":1080,"refreshRate":144.003,"x":0,"y":0,"scale":1.25,"transform":0,"mirrorOf":"none","currentFormat":"XRGB8888","vrr":false,"colorManagementPreset":"srgb","sdrBrightness":1,"sdrSaturation":1,"sdrMinLuminance":0.2,"sdrMaxLuminance":80,"disabled":false},
  {"name":"DP-2","width":2560,"height":1440,"refreshRate":60,"x":1920,"y":0,"scale":1,"transform":1,"mirrorOf":"none","currentFormat":"XRGB2101010","vrr":true,"colorManagementPreset":"srgb","sdrBrightness":1,"sdrSaturation":1,"sdrMinLuminance":0.2,"sdrMaxLuminance":80,"disabled":false}
]
JSON
cat >"$fixture/bin/hyprctl" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
case "${1:-}" in
  monitors) cat "$ASTRA_TEST_MONITORS" ;;
  reload)
    jq 'map(if .name == "DP-2" then .scale = 2 else . end)' "$ASTRA_TEST_MONITORS" >"$ASTRA_TEST_MONITORS.tmp"
    mv "$ASTRA_TEST_MONITORS.tmp" "$ASTRA_TEST_MONITORS"
    ;;
  configerrors) exit 0 ;;
  *) exit 2 ;;
esac
SH
chmod +x "$fixture/bin/hyprctl"

export HOME="$fixture/home"
export PATH="$fixture/bin:$PATH"
export ASTRA_TEST_MONITORS="$fixture/monitors.json"
export HYPR_MONITORS_FILE="$fixture/home/.config/hypr/monitors.lua"

"$root/scripts/astra-display-scale" DP-2 2 >/dev/null
"$root/scripts/astra-display-scale" DP-2 2 >/dev/null

config="$HYPR_MONITORS_FILE"
[[ "$(grep -Fc -- '-- quickshell-astra-output:DP-2' "$config")" -eq 1 ]]
grep -Fq -- '-- user comment must survive' "$config"
grep -Fq 'output = "DP-2"' "$config"
grep -Fq 'position = "1920x0"' "$config"
grep -Fq 'transform = 1' "$config"
grep -Fq 'bitdepth = 10' "$config"
grep -Fq 'vrr = 1' "$config"
! grep -Fq -- 'quickshell-astra-output:eDP-1' "$config"
[[ -f "$config.quickshell-astra-before-display-scale.bak" ]]
grep -Fq -- '-- user comment must survive' "$config.quickshell-astra-before-display-scale.bak"

echo "display scale helper tests passed"
