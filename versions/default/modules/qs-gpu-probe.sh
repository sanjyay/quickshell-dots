#!/usr/bin/env bash
set -u

debug=0
[[ "${1:-}" == "--debug" ]] && debug=1
drm_root="${QS_GPU_DRM_ROOT:-/sys/class/drm}"

log() { [[ "$debug" == 1 ]] && printf 'qs-gpu-probe: %s\n' "$*" >&2 || true; }
number_or_null() {
  local value="${1:-}"
  [[ "$value" =~ ^-?[0-9]+([.][0-9]+)?$ ]] && printf '%s' "$value" || printf 'null'
}
emit() {
  local status="$1" provider="$2" device="$3" name="$4"
  local temp="$5" util="$6" used="$7" total="$8" clock="$9" power="${10}"
  jq -cn \
    --arg status "$status" --arg provider "$provider" --arg device "$device" --arg name "$name" \
    --argjson temperatureC "$(number_or_null "$temp")" \
    --argjson usagePercent "$(number_or_null "$util")" \
    --argjson vramUsedMiB "$(number_or_null "$used")" \
    --argjson vramTotalMiB "$(number_or_null "$total")" \
    --argjson clockMHz "$(number_or_null "$clock")" \
    --argjson powerWatts "$(number_or_null "$power")" \
    --arg collectedAt "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    '{schemaVersion:1,status:$status,provider:$provider,device:$device,name:$name,
      temperatureC:$temperatureC,usagePercent:$usagePercent,vramUsedMiB:$vramUsedMiB,
      vramTotalMiB:$vramTotalMiB,clockMHz:$clockMHz,powerWatts:$powerWatts,
      collectedAt:$collectedAt,errorCode:null,message:null}'
}

nvidia_smi="${QS_GPU_NVIDIA_SMI:-$(command -v nvidia-smi 2>/dev/null || true)}"
if [[ -n "$nvidia_smi" && -x "$nvidia_smi" ]]; then
  line="$("$nvidia_smi" --query-gpu=name,temperature.gpu,utilization.gpu,memory.used,memory.total,clocks.gr,power.draw --format=csv,noheader,nounits 2>/dev/null | head -n1 || true)"
  if [[ -n "$line" ]]; then
    IFS=',' read -r name temp util used total clock power <<<"$line"
    for var in name temp util used total clock power; do
      printf -v "$var" '%s' "$(printf '%s' "${!var}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
    done
    device="nvidia0"
    for card in "$drm_root"/card[0-9]*; do
      [[ -r "$card/device/vendor" ]] || continue
      [[ "$(<"$card/device/vendor")" == "0x10de" ]] && { device="${card##*/}"; break; }
    done
    log "selected provider=nvidia device=$device source=$nvidia_smi"
    emit ok nvidia "$device" "$name" "$temp" "$util" "$used" "$total" "$clock" "$power"
    exit 0
  fi
fi

for card in "$drm_root"/card[0-9]*; do
  dev="$card/device"
  [[ -r "$dev/vendor" ]] || continue
  vendor="$(<"$dev/vendor")"
  case "$vendor" in 0x1002) provider=amd;; 0x10de) provider=nvidia;; 0x8086) provider=intel;; *) continue;; esac
  util= temp= used= total= clock= power=
  [[ -r "$dev/gpu_busy_percent" ]] && util="$(tr -dc '0-9' <"$dev/gpu_busy_percent")"
  for f in "$dev"/hwmon/hwmon*/temp*_input; do
    [[ -r "$f" ]] || continue
    temp="$(tr -dc '0-9' <"$f")"; [[ "$temp" -gt 1000 ]] 2>/dev/null && temp=$((temp / 1000))
    break
  done
  if [[ -r "$dev/mem_info_vram_used" && -r "$dev/mem_info_vram_total" ]]; then
    used=$(( $(<"$dev/mem_info_vram_used") / 1024 / 1024 ))
    total=$(( $(<"$dev/mem_info_vram_total") / 1024 / 1024 ))
  fi
  if [[ -r "$dev/gt_cur_freq_mhz" ]]; then clock="$(tr -dc '0-9' <"$dev/gt_cur_freq_mhz")"; fi
  for f in "$dev"/hwmon/hwmon*/power*_average; do
    [[ -r "$f" ]] || continue
    power="$(awk -v v="$(cat "$f")" 'BEGIN{printf "%.1f",v/1000000}')"; break
  done
  [[ -n "$util$temp$used$total$clock$power" ]] || { log "skipping unreadable ${card##*/} ($provider)"; continue; }
  log "selected provider=$provider device=${card##*/} source=sysfs"
  emit ok "$provider" "${card##*/}" "$provider GPU" "$temp" "$util" "$used" "$total" "$clock" "$power"
  exit 0
done

jq -cn --arg collectedAt "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  '{schemaVersion:1,status:"unavailable",provider:null,device:null,name:null,
    temperatureC:null,usagePercent:null,vramUsedMiB:null,vramTotalMiB:null,
    clockMHz:null,powerWatts:null,collectedAt:$collectedAt,
    errorCode:"no-readable-gpu",message:"No GPU with readable metrics was found"}'
