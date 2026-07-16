#!/usr/bin/env bash
# Ensure Quickshell-owned Hyprland bindings exist without rewriting user config.
set -euo pipefail

keybindings="${HYPR_BINDINGS_CONF:-${HYPR_KEYBINDINGS_CONF:-$HOME/.config/hypr/bindings.conf}}"
launcher_toggle_line="bindd = SUPER SHIFT, SPACE, Toggle desktop provider, exec, bash -lc 'if [[ \"\$(qs-mode status)\" == quickshell ]]; then qs-mode omarchy; else qs-mode quickshell; fi'"
managed_lines=(
  "unbind = SUPER, SPACE"
  "bind = SUPER, SPACE, exec, qs -c bar ipc call launcher open"
  "unbind = SUPER SHIFT, SPACE"
  "$launcher_toggle_line"
)
legacy_lines=(
  "bindd = SUPER SHIFT, SPACE, Refresh Quickshell bar, exec, bash -lc 'qs -c bar kill; sleep 0.2; qs -n -d -c bar'"
  "bindd = SUPER SHIFT, SPACE, Toggle-refresh Quickshell bar, exec, bash -lc 'qs -c bar kill >/dev/null 2>&1 || true; sleep 0.35; qs -n -d -c bar'"
)

mkdir -p "$(dirname "$keybindings")"

if [[ ! -e "$keybindings" ]]; then
  printf '%s\n' "${managed_lines[@]}" > "$keybindings"
  printf 'Hyprland Quickshell bindings: file created\n'
  exit 0
fi

tmp="$(mktemp)"
changed=0
while IFS= read -r line || [[ -n "$line" ]]; do
  skip=0
  for legacy in "${legacy_lines[@]}"; do
    if [[ "$line" == "$legacy" ]]; then
      skip=1
      changed=1
      break
    fi
  done
  [[ "$skip" -eq 1 ]] && continue
  printf '%s\n' "$line" >> "$tmp"
done < "$keybindings"
if [[ "$changed" -eq 1 ]]; then
  mv "$tmp" "$keybindings"
else
  rm -f "$tmp"
fi

missing=()
for line in "${managed_lines[@]}"; do
  grep -Fxq "$line" "$keybindings" || missing+=("$line")
done

if ((${#missing[@]} == 0)); then
  printf 'Hyprland Quickshell bindings: bindings already present\n'
  exit 0
fi

if [[ -s "$keybindings" ]]; then
  last_byte="$(tail -c 1 "$keybindings" | od -An -t u1 | tr -d ' ')"
  if [[ "$last_byte" != "10" ]]; then
    printf '\n' >> "$keybindings"
  fi
fi
for line in "${missing[@]}"; do
  printf '%s\n' "$line" >> "$keybindings"
done

printf 'Hyprland Quickshell bindings: missing bindings added\n'
