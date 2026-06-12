#!/usr/bin/env bash
# Refreshes the AUR known-infected list for the updater's security gate.
# Pulls the maintained (unpinned) Atomic Arch package list, validates it and
# atomically replaces ~/.local/share/qs-aur-blacklist.txt.
# Entries in the local supplement (qs-aur-blacklist.local.txt) are merged into
# every refresh, so ad-hoc additions survive the periodic overwrite.
# Fail-closed: any fetch/validation error keeps the previous list and exits
# nonzero — the gate then keeps working from the last good copy.
set -uo pipefail

DEST="${QS_AUR_BLACKLIST_LIST:-$HOME/.local/share/qs-aur-blacklist.txt}"
LOCAL="${QS_AUR_BLACKLIST_LOCAL:-$HOME/.local/share/qs-aur-blacklist.local.txt}"
MIN_COUNT="${QS_GATE_MIN:-100}"   # a "list" below this is treated as bogus
# Live feeds only: every URL must update in place (unpinned raw URLs).
# Dated snapshots (pastes, pinned gist revisions, mailing-list posts) belong
# in the local supplement instead — they never change after publication.
URLS=(
  "https://gist.githubusercontent.com/quantenProjects/3f768dce7331618310f016d975bf8547/raw/packages"
)

# Union merge: fetch every source, keep going if one fails; fail-closed only
# when none of them could be fetched.
raw="$(mktemp)"; part="$(mktemp)"; trap 'rm -f "$raw" "$part"' EXIT
fetched=0
for url in "${URLS[@]}"; do
  : > "$part"
  if command -v curl >/dev/null 2>&1; then
    curl -sfL --max-time 30 "$url" -o "$part" 2>/dev/null || continue
  elif command -v wget >/dev/null 2>&1; then
    wget -qO "$part" --timeout=30 "$url" 2>/dev/null || continue
  else
    break
  fi
  cat "$part" >> "$raw"; printf '\n' >> "$raw"
  fetched=$((fetched+1))
done
if [ "$fetched" -eq 0 ]; then
  echo "qs-aur-blacklist-fetch: all downloads failed — keeping previous list" >&2
  exit 1
fi

# Sanitize hard: only valid pacman package-name tokens survive, one per line,
# deduped. Anything else in the payload (markup, commands, garbage) is dropped.
clean="$(tr -d '\042\047' < "$raw" | tr ' \t,' '\n\n\n' \
         | grep -E '^[a-zA-Z0-9][a-zA-Z0-9@._+-]*$' | sort -u)"
count="$(printf '%s\n' "$clean" | grep -c . || true)"
if [ "$count" -lt "$MIN_COUNT" ]; then
  echo "qs-aur-blacklist-fetch: list too short ($count < $MIN_COUNT) — keeping previous list" >&2
  exit 1
fi

# Merge the local supplement, sanitized exactly like the fetched payload.
extra_count=0
if [ -s "$LOCAL" ]; then
  extra="$(tr -d '\042\047' < "$LOCAL" | tr ' \t,' '\n\n\n' \
           | grep -E '^[a-zA-Z0-9][a-zA-Z0-9@._+-]*$' | sort -u)"
  extra_count="$(printf '%s\n' "$extra" | grep -c . || true)"
  if [ "$extra_count" -gt 0 ]; then
    clean="$(printf '%s\n%s\n' "$clean" "$extra" | grep . | sort -u)"
    count="$(printf '%s\n' "$clean" | grep -c . || true)"
  fi
fi

mkdir -p "$(dirname "$DEST")"
tmp="$(mktemp "$DEST.XXXXXX")" || exit 1
printf '%s\n' "$clean" > "$tmp" || { rm -f "$tmp"; exit 1; }
chmod 644 "$tmp"
mv -f "$tmp" "$DEST"   # same directory ⇒ atomic rename
echo "qs-aur-blacklist-fetch: $count packages → $DEST ($extra_count from local supplement)"
