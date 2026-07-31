#!/usr/bin/env bash
set -euo pipefail

input=${1:?recording path required}
output=${2:?thumbnail path required}
[[ -f $input && -s $input ]] || exit 10
mkdir -p -- "$(dirname -- "$output")"

previous_size=-1
for delay in 0.25 0.5 1 2; do
  size=$(stat -c %s -- "$input" 2>/dev/null || printf 0)
  if (( size > 0 && size == previous_size )) &&
     ffprobe -v error -select_streams v:0 -show_entries stream=codec_type \
       -of csv=p=0 -- "$input" 2>/dev/null | grep -qx video; then
    tmp=$(mktemp --tmpdir="$(dirname -- "$output")" .history-preview.XXXXXX.jpg)
    trap 'rm -f -- "${tmp:-}"' EXIT
    if command -v ffmpegthumbnailer >/dev/null 2>&1; then
      ffmpegthumbnailer -i "$input" -o "$tmp" -s 640 -q 7 >/dev/null 2>&1
    else
      ffmpeg -y -ss 0.1 -i "$input" -frames:v 1 -q:v 3 "$tmp" -loglevel error >/dev/null 2>&1
    fi
    [[ -s $tmp ]] || exit 12
    mv -f -- "$tmp" "$output"
    trap - EXIT
    exit 0
  fi
  previous_size=$size
  sleep "$delay"
done
exit 11
