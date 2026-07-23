#!/usr/bin/env bash
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$repo/scripts/qs-artifact-manifest.sh"
tmp="$(mktemp -d)"
trap 'rm -rf -- "$tmp"' EXIT

[[ "$(qs_artifact_destination "$tmp/home" local-bin/qs-mode)" == "$tmp/home/.local/bin/qs-mode" ]]
[[ "$(qs_artifact_destination "$tmp/home" user-unit/example.service)" == "$tmp/home/.config/systemd/user/example.service" ]]
if qs_artifact_destination "$tmp/home" local-bin/../escape >/dev/null; then
  printf 'FAIL: traversal destination accepted\n' >&2; exit 1
fi
if qs_artifact_destination "$tmp/home" unknown/file >/dev/null; then
  printf 'FAIL: unknown destination prefix accepted\n' >&2; exit 1
fi

rows=0
count_row() { rows=$((rows + 1)); }
qs_artifacts_each "$repo/scripts/qs-owned-artifacts.tsv" mandatory count_row
[[ "$rows" -gt 0 ]] || { printf 'FAIL: no mandatory rows visited\n' >&2; exit 1; }

printf 'ok (confined owned-artifact manifest resolver: %d mandatory rows)\n' "$rows"
