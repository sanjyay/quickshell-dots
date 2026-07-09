#!/usr/bin/env bash
# Ensure Super+Space opens the Quickshell launcher without rewriting user config.
set -euo pipefail

keybindings="${HYPR_BINDINGS_CONF:-${HYPR_KEYBINDINGS_CONF:-$HOME/.config/hypr/bindings.conf}}"
unbind_line="unbind = SUPER, SPACE"
bind_line="bind = SUPER, SPACE, exec, qs -c bar ipc call launcher open"

mkdir -p "$(dirname "$keybindings")"

if [[ ! -e "$keybindings" ]]; then
  printf '%s\n%s\n' "$unbind_line" "$bind_line" > "$keybindings"
  printf 'Hyprland launcher binding: file created\n'
  exit 0
fi

missing=()
grep -Fxq "$unbind_line" "$keybindings" || missing+=("$unbind_line")
grep -Fxq "$bind_line" "$keybindings" || missing+=("$bind_line")

if ((${#missing[@]} == 0)); then
  printf 'Hyprland launcher binding: binding already present\n'
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

printf 'Hyprland launcher binding: missing binding added\n'
