#!/usr/bin/env bash
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
manifest="$repo/scripts/qs-owned-artifacts.tsv"
tmp="$(mktemp -d)"
trap 'rm -rf -- "$tmp"' EXIT

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
[[ -f "$manifest" ]] || fail "owned-artifact manifest missing"

while IFS=$'\t' read -r source destination mode policy extra; do
  [[ -z "$source" || "$source" == \#* ]] && continue
  [[ -z "$extra" ]] || fail "too many fields for $source"
  [[ -f "$repo/$source" ]] || fail "manifest source missing: $source"
  [[ "$destination" != /* && "$destination" != *..* ]] || fail "unsafe destination key: $destination"
  [[ "$mode" == 755 || "$mode" == 644 ]] || fail "invalid mode for $source: $mode"
  case "$policy" in
    mandatory|foreign-guarded|optional-existing|optional-ai|optional-ai-claude|optional-ai-codex|optional-ai-opencode) ;;
    *) fail "unknown policy for $source: $policy" ;;
  esac
  printf '%s\n' "$destination" >> "$tmp/destinations"
done < "$manifest"

duplicates="$(sort "$tmp/destinations" | uniq -d)"
[[ -z "$duplicates" ]] || fail "duplicate owned destinations: $duplicates"

# Installer and post-update consume mandatory rows. Standalone uninstall
# compatibility remains explicit and version-independent.
grep -Fq 'source "$manifest_lib"' "$repo/install.sh" || fail "installer does not load manifest reader"
grep -Fq 'qs_artifacts_each "$manifest" mandatory' "$repo/install.sh" || fail "installer does not consume mandatory rows"
grep -Fq 'source "$manifest_lib"' "$repo/scripts/qs-shell-post-update.sh" || fail "post-update does not load manifest reader"
grep -Fq 'qs_artifacts_each "$manifest" mandatory' "$repo/scripts/qs-shell-post-update.sh" || fail "post-update does not consume mandatory rows"
for policy in foreign-guarded optional-existing optional-ai optional-ai-claude optional-ai-codex optional-ai-opencode; do
  grep -Fq "qs_artifacts_each \"\$manifest\" $policy" "$repo/install.sh" || fail "installer does not consume $policy rows"
  grep -Fq "qs_artifacts_each \"\$manifest\" $policy" "$repo/scripts/qs-shell-post-update.sh" || fail "post-update does not consume $policy rows"
done
while IFS=$'\t' read -r source destination mode policy; do
  [[ -z "$source" || "$source" == \#* ]] && continue
  basename="${destination##*/}"
  grep -Fq "$basename" "$repo/uninstall.sh" || fail "uninstaller lacks $basename"
done < "$manifest"

printf 'ok (owned-artifact manifest: %s destinations; all install/update policies active)\n' "$(wc -l < "$tmp/destinations")"
