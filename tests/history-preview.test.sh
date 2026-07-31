#!/usr/bin/env bash
set -euo pipefail
repo="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
tmp=$(mktemp -d)
trap 'rm -rf -- "$tmp"' EXIT
mkdir -p "$tmp/bin" "$tmp/out"
printf video >"$tmp/recording.mp4"

cat >"$tmp/bin/ffprobe" <<'SH'
#!/usr/bin/env bash
count_file="${PREVIEW_TEST_COUNT:?}"
count=$(cat "$count_file" 2>/dev/null || echo 0)
count=$((count + 1)); printf '%s\n' "$count" >"$count_file"
(( count >= 2 )) && printf 'video\n'
SH
cat >"$tmp/bin/ffmpegthumbnailer" <<'SH'
#!/usr/bin/env bash
while (($#)); do [[ $1 == -o ]] && { shift; output=$1; }; shift; done
printf jpeg >"$output"
SH
chmod +x "$tmp/bin/ffprobe" "$tmp/bin/ffmpegthumbnailer"
PREVIEW_TEST_COUNT="$tmp/count" PATH="$tmp/bin:$PATH" \
  "$repo/scripts/history-recording-preview.sh" "$tmp/recording.mp4" "$tmp/out/thumb.jpg"
[[ -s "$tmp/out/thumb.jpg" ]]
[[ ! -e "$tmp/out/.history-preview" ]]
[[ $(cat "$tmp/count") -ge 2 ]]
echo "PASS: preview waits for stability, retries metadata, and publishes atomically"
