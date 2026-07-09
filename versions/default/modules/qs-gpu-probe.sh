#!/usr/bin/env bash
set -u

debug=0
[ "${1:-}" = "--debug" ] && debug=1

emit_debug() {
  [ "$debug" = 1 ] && printf 'DEBUG %s\n' "$*"
}

to_c() {
  local v="${1:-}"
  [ -n "$v" ] || return 1
  case "$v" in *[!0-9-]*) return 1;; esac
  [ "$v" -gt 1000 ] 2>/dev/null && v=$((v / 1000))
  printf '%s\n' "$v"
}

bytes_to_mib() {
  local v="${1:-}"
  [ -n "$v" ] || return 1
  case "$v" in *[!0-9]*) return 1;; esac
  printf '%s\n' $((v / 1024 / 1024))
}

first_temp_for_device() {
  local dev="$1" f name label v
  for f in "$dev"/hwmon/hwmon*/temp*_input; do
    [ -r "$f" ] || continue
    name="$(cat "${f%/*}/name" 2>/dev/null || true)"
    label="$(cat "${f%_input}_label" 2>/dev/null || true)"
    v="$(cat "$f" 2>/dev/null || true)"
    v="$(to_c "$v" 2>/dev/null || true)"
    [ -n "$v" ] || continue
    emit_debug "temp_source=$f name=$name label=$label value_c=$v"
    printf '%s\n' "$v"
    return 0
  done
  return 1
}

probe_nvidia() {
  command -v nvidia-smi >/dev/null 2>&1 || return 1
  local line temp used total util
  line="$(nvidia-smi --query-gpu=temperature.gpu,memory.used,memory.total,utilization.gpu --format=csv,noheader,nounits 2>/dev/null | head -1 || true)"
  [ -n "$line" ] || return 1
  IFS=',' read -r temp used total util <<EOF
$line
EOF
  temp="$(printf '%s' "$temp" | tr -dc '0-9')"
  used="$(printf '%s' "$used" | tr -dc '0-9')"
  total="$(printf '%s' "$total" | tr -dc '0-9')"
  util="$(printf '%s' "$util" | tr -dc '0-9')"
  [ -n "$temp" ] || return 1
  emit_debug "vendor=nvidia source=nvidia-smi raw=$line"
  printf 'GPU nvidia %s %s %s %s\n' "${util:---}" "${temp:---}" "${used:---}" "${total:---}"
  return 0
}

probe_drm() {
  local card dev vendor vendor_name driver util temp used total
  for card in /sys/class/drm/card*; do
    dev="$card/device"
    [ -d "$dev" ] || continue
    [ -r "$dev/vendor" ] || continue
    vendor="$(cat "$dev/vendor" 2>/dev/null || true)"
    vendor_name=""
    case "$vendor" in
      0x1002) vendor_name="amd" ;;
      0x10de) vendor_name="nvidia" ;;
      0x8086) vendor_name="intel" ;;
      *) vendor_name="unknown" ;;
    esac
    [ "$vendor_name" != "unknown" ] || continue

    util="--"; temp="--"; used="--"; total="--"
    if [ -r "$dev/gpu_busy_percent" ]; then
      util="$(cat "$dev/gpu_busy_percent" 2>/dev/null | tr -dc '0-9' || true)"
      [ -n "$util" ] || util="--"
    fi
    temp="$(first_temp_for_device "$dev" 2>/dev/null || true)"
    [ -n "$temp" ] || temp="--"

    if [ "$vendor_name" = "amd" ]; then
      if [ -r "$dev/mem_info_vram_used" ] && [ -r "$dev/mem_info_vram_total" ]; then
        used="$(bytes_to_mib "$(cat "$dev/mem_info_vram_used" 2>/dev/null)" 2>/dev/null || true)"
        total="$(bytes_to_mib "$(cat "$dev/mem_info_vram_total" 2>/dev/null)" 2>/dev/null || true)"
        [ -n "$used" ] || used="--"
        [ -n "$total" ] || total="--"
      fi
    fi

    emit_debug "vendor=$vendor_name source=$dev util=$util temp=$temp vram_used_mib=$used vram_total_mib=$total"
    printf 'GPU %s %s %s %s %s\n' "$vendor_name" "$util" "$temp" "$used" "$total"
    return 0
  done
  return 1
}

probe_nvidia || probe_drm || {
  emit_debug "vendor=none source=unavailable"
  printf 'GPU none -- -- -- --\n'
}
