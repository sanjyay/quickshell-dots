#!/usr/bin/env bash
set -Eeuo pipefail

PLUGIN_ID="io.github.sanjyay.quickshell-rise"
STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}/quickshell-rise"
STATE_FILE="$STATE_HOME/install-state.json"
TARGET="$HOME/.config/omarchy/plugins/$PLUGIN_ID"
SHELL_CONFIG="$HOME/.config/omarchy/shell.json"
BINDINGS="$HOME/.config/hypr/bindings.lua"
BLOCK_BEGIN="-- BEGIN QUICKSHELL-RISE MANAGED BLOCK"
BLOCK_END="-- END QUICKSHELL-RISE MANAGED BLOCK"
LOOKNFEEL="$HOME/.config/hypr/looknfeel.lua"
BLUR_BLOCK_BEGIN="-- BEGIN QUICKSHELL-RISE HISTORY BLUR"
BLUR_BLOCK_END="-- END QUICKSHELL-RISE HISTORY BLUR"
IDLE_WRAPPER="$HOME/.local/bin/quickshell-rise-idle-toggle"

info() { printf '==> %s\n' "$*"; }
warn() { printf '!! %s\n' "$*" >&2; }
have() { command -v "$1" >/dev/null 2>&1; }

previous_bar="omarchy.bar"
shell_backup=""
if [[ -f "$STATE_FILE" ]]; then
  jq -e --arg id "$PLUGIN_ID" '.schemaVersion == 1 and .pluginId == $id' "$STATE_FILE" >/dev/null ||
    { warn "installation state is invalid; only marker-owned cleanup will be attempted"; }
  previous_bar="$(jq -r '.previousBarId // "omarchy.bar"' "$STATE_FILE" 2>/dev/null || printf omarchy.bar)"
  shell_backup="$(jq -r '.previousShellConfigBackup // empty' "$STATE_FILE" 2>/dev/null || true)"
fi

if have omarchy-shell && omarchy-shell shell ping >/dev/null 2>&1; then
  if ! omarchy bar use "$previous_bar" >/dev/null 2>&1; then
    warn "previous bar '$previous_bar' is unavailable; restoring omarchy.bar"
    omarchy bar use omarchy.bar >/dev/null
  fi
  omarchy plugin disable "$PLUGIN_ID" >/dev/null 2>&1 || true
fi

if [[ -n "$shell_backup" && -f "$shell_backup" ]] &&
   jq -e '.version == 1' "$shell_backup" >/dev/null 2>&1; then
  install -m 600 "$shell_backup" "$SHELL_CONFIG"
fi

if [[ -f "$BINDINGS" ]]; then
  temp="$(mktemp "${TMPDIR:-/tmp}/quickshell-rise.bindings.XXXXXX")"
  trap 'rm -f -- "${temp:-}"' EXIT
  awk -v begin="$BLOCK_BEGIN" -v end="$BLOCK_END" '
    $0 == begin {
      begin_line=$0
      unbind_line=""; bind_line=""; end_line=""
      if ((getline unbind_line) > 0 &&
          (getline bind_line) > 0 &&
          (getline end_line) > 0 &&
          unbind_line == "hl.unbind(\"SUPER + CTRL + V\")" &&
          bind_line == "o.bind(\"SUPER + CTRL + V\", \"Quickshell Rise clipboard history\", \"omarchy-shell quickshell-rise-clipboard toggle\")" &&
          end_line == end) next
      print begin_line
      if (unbind_line != "") print unbind_line
      if (bind_line != "") print bind_line
      if (end_line != "") print end_line
      next
    }
    { print }
  ' "$BINDINGS" >"$temp"
  if have lua; then lua -e "assert(loadfile('$temp'))"; fi
  install -m 644 "$temp" "$BINDINGS"
  rm -f -- "$temp"
  trap - EXIT
fi
if [[ -f "$LOOKNFEEL" ]]; then
  temp="$(mktemp "${TMPDIR:-/tmp}/quickshell-rise.looknfeel.XXXXXX")"
  trap 'rm -f -- "${temp:-}"' EXIT
  awk -v begin="$BLUR_BLOCK_BEGIN" -v end="$BLUR_BLOCK_END" '
    $0 == begin { managed=1; next }
    $0 == end { managed=0; next }
    !managed { print }
  ' "$LOOKNFEEL" >"$temp"
  if have lua; then lua -e "assert(loadfile('$temp'))"; fi
  install -m 644 "$temp" "$LOOKNFEEL"
  rm -f -- "$temp"
  trap - EXIT
fi
if [[ -f "$IDLE_WRAPPER" ]] &&
   grep -Fq 'quickshell-rise-owned-idle-toggle' "$IDLE_WRAPPER"; then
  rm -f -- "$IDLE_WRAPPER"
fi
rm -f -- "$HOME/.cache/quickshell/app-launcher/apps.json"
rmdir -- "$HOME/.cache/quickshell/app-launcher" 2>/dev/null || true
rm -rf -- "$HOME/.cache/quickshell-history-thumbs"
holiday_cache="${XDG_CACHE_HOME:-$HOME/.cache}/quickshell-rise/holidays"
rm -rf -- "$holiday_cache"
rmdir -- "${XDG_CACHE_HOME:-$HOME/.cache}/quickshell-rise" 2>/dev/null || true
rm -f -- "${XDG_STATE_HOME:-$HOME/.local/state}/quickshell-rise/holiday-settings.json"

if [[ -d "$TARGET" && -f "$TARGET/manifest.json" ]] &&
   [[ "$(jq -r '.id // empty' "$TARGET/manifest.json" 2>/dev/null)" == "$PLUGIN_ID" ]]; then
  # Bundled holiday provider data and validation helpers are owned by this
  # plugin tree and are removed with the same manifest ownership guard.
  if have omarchy-shell && omarchy-shell shell ping >/dev/null 2>&1; then
    omarchy plugin remove "$PLUGIN_ID" --yes >/dev/null
  else
    rm -rf -- "$TARGET"
  fi
elif [[ -e "$TARGET" ]]; then
  warn "leaving unrecognized plugin path untouched: $TARGET"
fi

# Marker-guarded cleanup for artifacts owned by pre-Quattro releases.
legacy_bar="$HOME/.config/quickshell/bar"
if [[ -d "$legacy_bar" && -f "$legacy_bar/.qsrise" ]]; then rm -rf -- "$legacy_bar"; fi
for legacy in \
  "$HOME/.local/bin/qs-mode" \
  "$HOME/.local/bin/swayosd-client" \
  "$HOME/.config/omarchy/hooks/theme-set.d/50-quickshell-bar.sh" \
  "$HOME/.config/omarchy/post-boot.d/quickshell-rise"; do
  if [[ -f "$legacy" ]] && grep -Eqi 'quickshell-rise|qs-rise|quickshell bar' "$legacy"; then rm -f -- "$legacy"; fi
done
rm -f -- \
  "$HOME/.config/systemd/user/elephant.service.d/50-qs-rise-clipboard-privacy.conf" \
  "$HOME/.local/lib/qs-rise/elephant-bin/wl-paste"
rmdir -- "$HOME/.config/systemd/user/elephant.service.d" \
  "$HOME/.local/lib/qs-rise/elephant-bin" "$HOME/.local/lib/qs-rise" 2>/dev/null || true

for unit in claude-usage codex-usage opencode-usage qs-shell-update-check \
  quickshell-rise-holiday-annual-update; do
  systemctl --user disable --now "$unit.timer" >/dev/null 2>&1 || true
  rm -f -- "$HOME/.config/systemd/user/$unit.service" "$HOME/.config/systemd/user/$unit.timer"
done
rm -rf -- "${XDG_DATA_HOME:-$HOME/.local/share}/quickshell-rise/holidays"
rmdir -- "${XDG_DATA_HOME:-$HOME/.local/share}/quickshell-rise" 2>/dev/null || true
for legacy_ai_script in claude-usage codex-usage opencode-usage; do
  legacy_ai_path="$HOME/.local/bin/$legacy_ai_script"
  if [[ -f "$legacy_ai_path" ]] &&
     grep -Fq "Quickshell" "$legacy_ai_path" &&
     grep -Eqi 'usage|quota' "$legacy_ai_path"; then
    rm -f -- "$legacy_ai_path"
  fi
done
systemctl --user daemon-reload >/dev/null 2>&1 || true

if have omarchy-shell && omarchy-shell shell ping >/dev/null 2>&1; then
  omarchy-shell shell rescanPlugins >/dev/null
  omarchy-shell shell ping >/dev/null
fi
if have hyprctl; then hyprctl reload >/dev/null; fi

rm -rf -- "$STATE_HOME"
info "Quickshell Rise removed; active bar is ${previous_bar:-omarchy.bar}"
