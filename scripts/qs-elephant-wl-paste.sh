#!/usr/bin/env bash
set -euo pipefail

real_wl_paste=/usr/bin/wl-paste
filter="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/qs-clipboard-filter.py"

for ((i = 1; i <= $#; i++)); do
  if [[ ${!i} == --watch || ${!i} == -w ]]; then
    before=("${@:1:i}")
    command=("${@:i+1}")
    ((${#command[@]} > 0)) || exec "$real_wl_paste" "$@"
    exec "$real_wl_paste" "${before[@]}" "$filter" "${command[@]}"
  fi
done

exec "$real_wl_paste" "$@"
