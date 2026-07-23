#!/usr/bin/env bash
# Verify a staged/installed bar against authoritative source configuration.
set -euo pipefail

[[ $# -eq 2 ]] || { printf 'usage: qs-verify-config-tree SOURCE DESTINATION\n' >&2; exit 2; }
source_tree="${1%/}"
destination="${2%/}"
[[ -d "$source_tree" ]] || { printf 'Config source is missing: %s\n' "$source_tree" >&2; exit 1; }
[[ -d "$destination" ]] || { printf 'Config destination is missing: %s\n' "$destination" >&2; exit 1; }

tmp="$(mktemp -d)"
trap 'rm -rf -- "$tmp"' EXIT
source_list="$tmp/source"
destination_list="$tmp/destination"

LC_ALL=C find "$source_tree" -type f ! -name quotes.txt -printf '%P\n' | sort > "$source_list"
LC_ALL=C find "$destination" -type f \
  ! -name quotes.txt ! -name .qsrise ! -name .qsrise-source \
  -printf '%P\n' | sort > "$destination_list"

if ! cmp -s "$source_list" "$destination_list"; then
  printf 'Config file inventory mismatch: %s -> %s\n' "$source_tree" "$destination" >&2
  diff -u "$source_list" "$destination_list" >&2 || true
  exit 1
fi

while IFS= read -r rel; do
  cmp -s "$source_tree/$rel" "$destination/$rel" || {
    printf 'Config content mismatch: %s\n' "$rel" >&2
    exit 1
  }
done < "$source_list"

[[ -f "$destination/quotes.txt" ]] || { printf 'Config quotes.txt is missing\n' >&2; exit 1; }
