#!/usr/bin/env bash
# Pre-install security gate for the Quickshell Arch updater.
#
# stdin : one update candidate per line, pipe-separated:  pkg|repo|old|new
#         repo ∈ system|aur   (passed through from the widget's S|/A| prefix)
# stdout: one JSON object per line.
#         First line is meta:  {"meta":"gate","blacklist":N,"degraded":B}
#         Then per package:    {"pkg","repo","old","new","verdict","reason"}
#           verdict ∈ OK | WARN | FAIL
#
# Pure function: reads only, installs nothing, needs no root, no jq, no eval.
set -uo pipefail

# Resolve blacklist source: explicit override wins, else first readable candidate.
# Stable copy first, Downloads as a fallback (so a fresh re-download still works).
if [ -n "${QS_AUR_BLACKLIST:-}" ]; then
  BLACKLIST_SRC="$QS_AUR_BLACKLIST"
else
  BLACKLIST_SRC=""
  for _c in "$HOME/.local/share/check-atomic-arch.sh" "$HOME/Downloads/check-atomic-arch.sh"; do
    [ -r "$_c" ] && { BLACKLIST_SRC="$_c"; break; }
  done
fi
MIN_COUNT="${QS_GATE_MIN:-100}"   # below this the blacklist is treated as degraded

# --- 1. Load blacklist WITHOUT eval --------------------------------------
# Extract the body between `KNOWN_INFECTED=(` and the closing `)`, strip any
# quotes, split on whitespace, keep only valid pkgname tokens. No execution.
declare -A INFECTED
load_local() {
  [ -r "$BLACKLIST_SRC" ] || return 0
  awk '/^KNOWN_INFECTED=\(/{f=1;next} /^[[:space:]]*\)/{f=0} f' "$BLACKLIST_SRC" \
    | tr -d '\042\047' \
    | tr ' \t' '\n\n' \
    | grep -E '^[a-zA-Z0-9][a-zA-Z0-9@._+-]*$'
}
while read -r p; do [ -n "$p" ] && INFECTED["$p"]=1; done < <(load_local)

# ${#INFECTED[@]} on an empty assoc array trips `set -u` on bash < 4.4
set +u; blacklist_count=${#INFECTED[@]}; set -u
degraded=false
[ "$blacklist_count" -lt "$MIN_COUNT" ] && degraded=true

# --- JSON emitter (printf-based, minimal escaping; no jq dependency) ------
jstr() { local s=${1//\\/\\\\}; s=${s//\"/\\\"}; printf '%s' "$s"; }
emit() { # pkg repo old new verdict reason
  printf '{"pkg":"%s","repo":"%s","old":"%s","new":"%s","verdict":"%s","reason":"%s"}\n' \
    "$(jstr "$1")" "$(jstr "$2")" "$(jstr "$3")" "$(jstr "$4")" "$5" "$(jstr "$6")"
}

# --- meta line first so the UI can show a degraded/limited-protection state
printf '{"meta":"gate","blacklist":%d,"degraded":%s}\n' "$blacklist_count" "$degraded"

# --- 2. Classify each update candidate -----------------------------------
while IFS='|' read -r pkg repo old new || [ -n "$pkg" ]; do
  [ -n "$pkg" ] || continue
  [ "$repo" = "aur" ] || repo="system"

  if [ -n "${INFECTED[$pkg]:-}" ]; then
    emit "$pkg" "$repo" "$old" "$new" "FAIL" "On Atomic Arch known-infected list"
    continue
  fi

  if [ "$repo" = "aur" ]; then
    # AUR is the Atomic Arch entry vector (orphan takeover -> malicious PKGBUILD).
    # Not blocked, but flagged for a manual PKGBUILD look.
    emit "$pkg" "$repo" "$old" "$new" "WARN" "AUR package — review PKGBUILD before building"
  else
    emit "$pkg" "$repo" "$old" "$new" "OK" ""
  fi
done

exit 0
