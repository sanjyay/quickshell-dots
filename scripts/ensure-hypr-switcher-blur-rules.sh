#!/usr/bin/env bash
# Ensure Quickshell-owned Hyprland layer blur rules exist without rewriting user config.
set -euo pipefail

looknfeel="${HYPR_LOOKNFEEL_CONF:-$HOME/.config/hypr/looknfeel.conf}"
begin="# >>> quickshell-rise managed switcher blur rules >>>"
end="# <<< quickshell-rise managed switcher blur rules <<<"

managed_block="$(cat <<'EOF'
# >>> quickshell-rise managed switcher blur rules >>>
layerrule = blur on, match:namespace quickshell-theme-switcher
layerrule = ignore_alpha 0, match:namespace quickshell-theme-switcher
layerrule = blur on, match:namespace quickshell-wallpaper-switcher
layerrule = ignore_alpha 0, match:namespace quickshell-wallpaper-switcher
layerrule = blur on, match:namespace quickshell-history
layerrule = ignore_alpha 0, match:namespace quickshell-history
# <<< quickshell-rise managed switcher blur rules <<<
EOF
)"

mkdir -p "$(dirname "$looknfeel")"

if [[ ! -e "$looknfeel" ]]; then
  printf '%s\n' "$managed_block" > "$looknfeel"
  printf 'Hyprland Quickshell switcher blur rules: file created\n'
  exit 0
fi

tmp="$(mktemp)"
removed=0
in_block=0
while IFS= read -r line || [[ -n "$line" ]]; do
  if [[ "$line" == "$begin" ]]; then
    in_block=1
    removed=1
    continue
  fi
  if [[ "$line" == "$end" ]]; then
    in_block=0
    continue
  fi
  [[ "$in_block" -eq 1 ]] && continue
  printf '%s\n' "$line" >> "$tmp"
done < "$looknfeel"

if [[ "$removed" -eq 1 ]]; then
  mv "$tmp" "$looknfeel"
else
  rm -f "$tmp"
fi

if [[ -s "$looknfeel" ]]; then
  last_byte="$(tail -c 1 "$looknfeel" | od -An -t u1 | tr -d ' ')"
  if [[ "$last_byte" != "10" ]]; then
    printf '\n' >> "$looknfeel"
  fi
  printf '\n' >> "$looknfeel"
fi
printf '%s\n' "$managed_block" >> "$looknfeel"

printf 'Hyprland Quickshell switcher blur rules: rules installed\n'
