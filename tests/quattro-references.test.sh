#!/usr/bin/env bash
set -euo pipefail

repo="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"

while IFS=: read -r file _ import_path; do
  import_path="${import_path#\"}"
  import_path="${import_path%\"*}"
  [[ "$import_path" == .* ]] || continue
  resolved="$(realpath -m "$(dirname -- "$file")/$import_path")"
  [[ -e "$resolved" ]] || {
    printf 'FAIL: unresolved QML import %s from %s\n' "$import_path" "$file" >&2
    exit 1
  }
done < <(cd "$repo" && rg -n '^import "[.][^"]*"' rise versions tests/fixtures -g '*.qml')

while IFS= read -r script; do
  bash -n "$script"
done < <(rg -l '^#!/(usr/bin/env )?bash' "$repo/scripts" "$repo/hooks" "$repo/contrib")

printf 'PASS: plugin-relative QML imports and retained shell sources resolve\n'
