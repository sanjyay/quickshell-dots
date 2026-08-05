#!/usr/bin/env bash
set -Eeuo pipefail

PLUGIN_ID="io.github.sanjyay.quickshell-astra"
LEGACY_PLUGIN_ID="io.github.sanjyay.quickshell-rise"
STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}/quickshell-astra"
STATE_FILE="$STATE_HOME/install-state.json"
LEGACY_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}/quickshell-rise"
LEGACY_STATE_FILE="$LEGACY_STATE_HOME/install-state.json"
TARGET="$HOME/.config/omarchy/plugins/$PLUGIN_ID"
LEGACY_TARGET="$HOME/.config/omarchy/plugins/$LEGACY_PLUGIN_ID"
SHELL_CONFIG="$HOME/.config/omarchy/shell.json"
BINDINGS="$HOME/.config/hypr/bindings.lua"
BLOCK_BEGIN="-- BEGIN QUICKSHELL-ASTRA MANAGED BLOCK"
BLOCK_END="-- END QUICKSHELL-ASTRA MANAGED BLOCK"
LEGACY_BLOCK_BEGIN="-- BEGIN QUICKSHELL-RISE MANAGED BLOCK"
LEGACY_BLOCK_END="-- END QUICKSHELL-RISE MANAGED BLOCK"
LOOKNFEEL="$HOME/.config/hypr/looknfeel.lua"
MONITORS="$HOME/.config/hypr/monitors.lua"
DISPLAY_SCALE_BLOCK_BEGIN="-- BEGIN QUICKSHELL-ASTRA DISPLAY SCALE"
DISPLAY_SCALE_BLOCK_END="-- END QUICKSHELL-ASTRA DISPLAY SCALE"
BLUR_BLOCK_BEGIN="-- BEGIN QUICKSHELL-ASTRA HISTORY BLUR"
BLUR_BLOCK_END="-- END QUICKSHELL-ASTRA HISTORY BLUR"
LEGACY_BLUR_BLOCK_BEGIN="-- BEGIN QUICKSHELL-RISE HISTORY BLUR"
LEGACY_BLUR_BLOCK_END="-- END QUICKSHELL-RISE HISTORY BLUR"
IDLE_WRAPPER="$HOME/.local/bin/quickshell-astra-idle-toggle"
MPV_WRAPPER="$HOME/.local/bin/mpv"
LEGACY_SCREENRECORD_WRAPPER="$HOME/.local/bin/omarchy-capture-screenrecording"
LEGACY_SCREENRECORD_SHIM_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/quickshell-astra/screenrecord-bin"

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
elif [[ -f "$LEGACY_STATE_FILE" ]]; then
  jq -e --arg id "$LEGACY_PLUGIN_ID" '.schemaVersion == 1 and .pluginId == $id' "$LEGACY_STATE_FILE" >/dev/null ||
    { warn "legacy installation state is invalid; only marker-owned cleanup will be attempted"; }
  previous_bar="$(jq -r '.previousBarId // "omarchy.bar"' "$LEGACY_STATE_FILE" 2>/dev/null || printf omarchy.bar)"
  shell_backup="$(jq -r '.previousShellConfigBackup // empty' "$LEGACY_STATE_FILE" 2>/dev/null || true)"
fi

if have omarchy-shell && omarchy-shell shell ping >/dev/null 2>&1; then
  if ! omarchy bar use "$previous_bar" >/dev/null 2>&1; then
    warn "previous bar '$previous_bar' is unavailable; restoring omarchy.bar"
    omarchy bar use omarchy.bar >/dev/null
  fi
  omarchy plugin disable "$PLUGIN_ID" >/dev/null 2>&1 || true
  omarchy plugin disable "$LEGACY_PLUGIN_ID" >/dev/null 2>&1 || true
fi

if [[ -n "$shell_backup" && -f "$shell_backup" ]] &&
   jq -e '.version == 1' "$shell_backup" >/dev/null 2>&1; then
  install -m 600 "$shell_backup" "$SHELL_CONFIG"
fi

if [[ -f "$BINDINGS" ]]; then
  temp="$(mktemp "${TMPDIR:-/tmp}/quickshell-astra.bindings.XXXXXX")"
  trap 'rm -f -- "${temp:-}"' EXIT
  awk -v begin="$BLOCK_BEGIN" -v end="$BLOCK_END" \
      -v legacy_begin="$LEGACY_BLOCK_BEGIN" -v legacy_end="$LEGACY_BLOCK_END" '
    $0 == begin || $0 == legacy_begin {
      begin_line=$0
      unbind_line=""; bind_line=""; end_line=""
      if ((getline unbind_line) > 0 &&
          (getline bind_line) > 0 &&
          (getline end_line) > 0 &&
          unbind_line == "hl.unbind(\"SUPER + CTRL + V\")" &&
          (bind_line == "o.bind(\"SUPER + CTRL + V\", \"Quickshell Astra clipboard history\", \"omarchy-shell quickshell-astra-clipboard toggle\")" ||
           bind_line == "o.bind(\"SUPER + CTRL + V\", \"Quickshell Rise clipboard history\", \"omarchy-shell quickshell-rise-clipboard toggle\")") &&
          (end_line == end || end_line == legacy_end)) next
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
  temp="$(mktemp "${TMPDIR:-/tmp}/quickshell-astra.looknfeel.XXXXXX")"
  trap 'rm -f -- "${temp:-}"' EXIT
  awk -v begin="$BLUR_BLOCK_BEGIN" -v end="$BLUR_BLOCK_END" \
      -v legacy_begin="$LEGACY_BLUR_BLOCK_BEGIN" -v legacy_end="$LEGACY_BLUR_BLOCK_END" '
    $0 == begin || $0 == legacy_begin { managed=1; next }
    $0 == end || $0 == legacy_end { managed=0; next }
    !managed { print }
  ' "$LOOKNFEEL" >"$temp"
  if have lua; then lua -e "assert(loadfile('$temp'))"; fi
  install -m 644 "$temp" "$LOOKNFEEL"
  rm -f -- "$temp"
  trap - EXIT
fi
if [[ -f "$MONITORS" ]] && grep -Fxq "$DISPLAY_SCALE_BLOCK_BEGIN" "$MONITORS" &&
   [[ "$(grep -Fxc -- "$DISPLAY_SCALE_BLOCK_BEGIN" "$MONITORS" || true)" -eq 1 ]] &&
   [[ "$(grep -Fxc -- "$DISPLAY_SCALE_BLOCK_END" "$MONITORS" || true)" -eq 1 ]]; then
  temp="$(mktemp "${TMPDIR:-/tmp}/quickshell-astra.monitors.XXXXXX")"
  trap 'rm -f -- "${temp:-}"' EXIT
  awk -v begin="$DISPLAY_SCALE_BLOCK_BEGIN" -v end="$DISPLAY_SCALE_BLOCK_END" '
    $0 == begin { managed=1; next }
    $0 == end { managed=0; next }
    !managed { print }
  ' "$MONITORS" >"$temp"
  if have lua; then lua -e "assert(loadfile('$temp'))"; fi
  install -m "$(stat -c '%a' "$MONITORS")" "$temp" "$MONITORS"
  rm -f -- "$temp"
  trap - EXIT
  rm -f -- "$MONITORS.quickshell-astra-before-display-scale.bak"
fi
if [[ -f "$IDLE_WRAPPER" ]] &&
   grep -Fq 'quickshell-astra-owned-idle-toggle' "$IDLE_WRAPPER"; then
  rm -f -- "$IDLE_WRAPPER"
fi
if [[ -f "$MPV_WRAPPER" ]] &&
   { grep -Fq 'quickshell-astra-owned-mpv-screenrecord-action' "$MPV_WRAPPER" ||
     grep -Fq 'quickshell-rise-owned-mpv-screenrecord-action' "$MPV_WRAPPER"; }; then
  rm -f -- "$MPV_WRAPPER"
fi
if [[ -f "$LEGACY_SCREENRECORD_WRAPPER" ]] &&
   grep -Fq 'quickshell-astra-owned-screenrecord-capture' "$LEGACY_SCREENRECORD_WRAPPER"; then
  rm -f -- "$LEGACY_SCREENRECORD_WRAPPER"
fi
if [[ -f "$LEGACY_SCREENRECORD_SHIM_DIR/omarchy-notification-send" ]] &&
   grep -Fq 'quickshell-astra-owned-screenrecord-notification' \
     "$LEGACY_SCREENRECORD_SHIM_DIR/omarchy-notification-send"; then
  rm -f -- "$LEGACY_SCREENRECORD_SHIM_DIR/omarchy-notification-send"
fi
rmdir -- "$LEGACY_SCREENRECORD_SHIM_DIR" 2>/dev/null || true
rm -f -- "$HOME/.cache/quickshell/app-launcher/apps.json"
rmdir -- "$HOME/.cache/quickshell/app-launcher" 2>/dev/null || true
rm -rf -- "$HOME/.cache/quickshell-history-thumbs"
holiday_cache="${XDG_CACHE_HOME:-$HOME/.cache}/quickshell-astra/holidays"
rm -rf -- "$holiday_cache"
rmdir -- "${XDG_CACHE_HOME:-$HOME/.cache}/quickshell-astra" 2>/dev/null || true
rm -f -- "${XDG_STATE_HOME:-$HOME/.local/state}/quickshell-astra/holiday-settings.json"

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

if [[ -d "$LEGACY_TARGET" && -f "$LEGACY_TARGET/manifest.json" ]] &&
   [[ "$(jq -r '.id // empty' "$LEGACY_TARGET/manifest.json" 2>/dev/null)" == "$LEGACY_PLUGIN_ID" ]]; then
  rm -rf -- "$LEGACY_TARGET"
elif [[ -e "$LEGACY_TARGET" ]]; then
  warn "leaving unrecognized legacy plugin path untouched: $LEGACY_TARGET"
fi

# Marker-guarded cleanup for artifacts owned by pre-Quattro releases.
legacy_bar="$HOME/.config/quickshell/bar"
if [[ -d "$legacy_bar" && -f "$legacy_bar/.qsrise" ]]; then rm -rf -- "$legacy_bar"; fi
for legacy in \
  "$HOME/.local/bin/qs-mode" \
  "$HOME/.local/bin/swayosd-client" \
  "$HOME/.config/omarchy/hooks/theme-set.d/50-quickshell-bar.sh" \
  "$HOME/.config/omarchy/post-boot.d/quickshell-astra" \
  "$HOME/.config/omarchy/post-boot.d/quickshell-rise"; do
  if [[ -f "$legacy" ]] && grep -Eqi 'quickshell-(astra|rise)|qs-(astra|rise)|quickshell bar' "$legacy"; then rm -f -- "$legacy"; fi
done
rm -f -- \
  "$HOME/.config/systemd/user/elephant.service.d/50-qs-astra-clipboard-privacy.conf" \
  "$HOME/.local/lib/qs-astra/elephant-bin/wl-paste"
rmdir -- "$HOME/.config/systemd/user/elephant.service.d" \
  "$HOME/.local/lib/qs-astra/elephant-bin" "$HOME/.local/lib/qs-astra" 2>/dev/null || true

for unit in claude-usage codex-usage opencode-usage qs-shell-update-check \
  quickshell-astra-holiday-annual-update quickshell-rise-holiday-annual-update; do
  systemctl --user disable --now "$unit.timer" >/dev/null 2>&1 || true
  rm -f -- "$HOME/.config/systemd/user/$unit.service" "$HOME/.config/systemd/user/$unit.timer"
done
rm -rf -- "${XDG_DATA_HOME:-$HOME/.local/share}/quickshell-astra/holidays"
rm -rf -- "${XDG_DATA_HOME:-$HOME/.local/share}/quickshell-rise/holidays"
rmdir -- "${XDG_DATA_HOME:-$HOME/.local/share}/quickshell-astra" 2>/dev/null || true
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

for state_dir in "$STATE_HOME" "$LEGACY_STATE_HOME"; do
  rm -f -- "$state_dir/install-state.json" "$state_dir/shell.before.json" \
    "$state_dir/ai-usage.json" "$state_dir/holiday-settings.json" \
    "$state_dir/holiday-annual-update.json"
  rmdir -- "$state_dir" 2>/dev/null || true
done
info "Quickshell Astra removed; active bar is ${previous_bar:-omarchy.bar}"
