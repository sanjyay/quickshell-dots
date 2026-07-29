#!/usr/bin/env bash
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf -- "$tmp"' EXIT
source_tree="$tmp/source"
destination="$tmp/destination"
helper="$repo/scripts/qs-verify-config-tree.sh"
mkdir -p "$source_tree/modules" "$destination/modules"

printf 'root\n' > "$source_tree/shell.qml"
printf 'module\0data\n' > "$source_tree/modules/Test.qml"
printf 'source quotes\n' > "$source_tree/quotes.txt"
cp "$source_tree/shell.qml" "$destination/shell.qml"
cp "$source_tree/modules/Test.qml" "$destination/modules/Test.qml"
printf 'custom user quotes\n' > "$destination/quotes.txt"
printf 'default\n' > "$destination/.qsrise"
printf '/tmp/source\n' > "$destination/.qsrise-source"

bash "$helper" "$source_tree" "$destination"

printf 'extra\n' > "$destination/extra.qml"
if bash "$helper" "$source_tree" "$destination" >/dev/null 2>&1; then
  printf 'FAIL: extra destination file was accepted\n' >&2
  exit 1
fi
rm "$destination/extra.qml"

printf 'changed\n' > "$destination/modules/Test.qml"
if bash "$helper" "$source_tree" "$destination" >/dev/null 2>&1; then
  printf 'FAIL: content mismatch was accepted\n' >&2
  exit 1
fi
cp "$source_tree/modules/Test.qml" "$destination/modules/Test.qml"

rm "$destination/quotes.txt"
if bash "$helper" "$source_tree" "$destination" >/dev/null 2>&1; then
  printf 'FAIL: missing quotes.txt was accepted\n' >&2
  exit 1
fi

printf 'ok (isolated complete config-tree parity verifier)\n'
