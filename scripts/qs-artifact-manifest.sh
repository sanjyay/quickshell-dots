#!/usr/bin/env bash

qs_artifact_destination() {
  local home="$1" key="$2" prefix rest
  prefix="${key%%/*}"
  rest="${key#*/}"
  [[ "$key" == */* && "$rest" != *..* && "$rest" != /* ]] || return 2
  case "$prefix" in
    local-bin) printf '%s/.local/bin/%s\n' "$home" "$rest" ;;
    local-lib) printf '%s/.local/lib/%s\n' "$home" "$rest" ;;
    quickshell-bin) printf '%s/.config/quickshell/bin/%s\n' "$home" "$rest" ;;
    user-unit) printf '%s/.config/systemd/user/%s\n' "$home" "$rest" ;;
    omarchy-theme-hook) printf '%s/.config/omarchy/hooks/theme-set.d/%s\n' "$home" "$rest" ;;
    omarchy-post-boot) printf '%s/.config/omarchy/hooks/post-boot.d/%s\n' "$home" "$rest" ;;
    *) return 2 ;;
  esac
}

qs_artifacts_each() {
  local manifest="$1" wanted_policy="$2" callback="$3"
  local source destination mode policy extra
  while IFS=$'\t' read -r source destination mode policy extra; do
    [[ -z "$source" || "$source" == \#* ]] && continue
    [[ -z "$extra" && "$mode" =~ ^(644|755)$ ]] || return 2
    [[ "$policy" == "$wanted_policy" ]] || continue
    "$callback" "$source" "$destination" "$mode" "$policy" || return
  done < "$manifest"
}
