#!/usr/bin/env bash
# Quickshell Rise — uninstaller (version-agnostic; removes whatever is installed)
# Usage:
#   bash <(curl -fsSL https://raw.githubusercontent.com/sanjyay/quickshell-dots/main/uninstall.sh)
set -euo pipefail

DEST="$HOME/.config/quickshell/bar"

c_g=$'\e[32m'; c_y=$'\e[33m'; c_0=$'\e[0m'
info() { printf "%s==>%s %s\n" "$c_g" "$c_0" "$*"; }
warn() { printf "%s!!%s %s\n"  "$c_y" "$c_0" "$*"; }

# 0. ownership guard — refuse to touch ANYTHING if a config dir exists that we
# did not install (install.sh writes .qsrise). Checked before any removal so a
# foreign install aborts cleanly instead of losing helpers/units/lists first.
if [[ -d "$DEST" && ! -e "$DEST/.qsrise" ]]; then
  warn "$DEST was not installed by Quickshell Rise (no .qsrise marker) — leaving everything untouched."
  exit 1
fi

# 1. stop the running bar
# stop existing bar (supports both -c bar and -p $DEST modes)
if [[ -x "$HOME/.local/bin/qs-mode" ]]; then
  "$HOME/.local/bin/qs-mode" omarchy >/dev/null 2>&1 || true
fi
pkill -f "qs.*-c bar" 2>/dev/null && info "Stopped the bar" || true
pkill -f "quickshell -p $DEST" 2>/dev/null && info "Stopped the bar" || true

# 1b. remove the Claude usage backend, if it was installed (idempotent).
# Covers the current OAuth backend and any older split cookie/calc install.
unitdir="$HOME/.config/systemd/user"
bindir="$HOME/.local/bin"
launcher_toggle_binding="bindd = SUPER SHIFT, SPACE, Toggle desktop provider, exec, bash -lc 'if [[ \"\$(qs-mode status)\" == quickshell ]]; then qs-mode omarchy; else qs-mode quickshell; fi'"
remove_hypr_quickshell_bindings() {
  local keybindings="${HYPR_BINDINGS_CONF:-${HYPR_KEYBINDINGS_CONF:-$HOME/.config/hypr/bindings.conf}}"
  [[ -f "$keybindings" ]] || return 0

  local tmp removed=0 in_media_block=0 in_menu_block=0 in_notification_block=0
  tmp="$(mktemp)"
  while IFS= read -r line || [[ -n "$line" ]]; do
    if [[ "$line" == "# >>> quickshell-rise managed media bindings >>>" ]]; then
      in_media_block=1
      removed=1
      continue
    fi
    if [[ "$line" == "# <<< quickshell-rise managed media bindings <<<" ]]; then
      in_media_block=0
      continue
    fi
    if [[ "$line" == "# >>> quickshell-rise managed menu bindings >>>" ]]; then
      in_menu_block=1
      removed=1
      continue
    fi
    if [[ "$line" == "# <<< quickshell-rise managed menu bindings <<<" ]]; then
      in_menu_block=0
      continue
    fi
    if [[ "$line" == "# >>> quickshell-rise managed notification bindings >>>" ]]; then in_notification_block=1; removed=1; continue; fi
    if [[ "$line" == "# <<< quickshell-rise managed notification bindings <<<" ]]; then in_notification_block=0; continue; fi
    [[ "$in_media_block" -eq 1 ]] && continue
    [[ "$in_menu_block" -eq 1 ]] && continue
    [[ "$in_notification_block" -eq 1 ]] && continue
    case "$line" in
      "unbind = SUPER, SPACE"|\
      "bind = SUPER, SPACE, exec, qs -c bar ipc call launcher open"|\
      "unbind = SUPER SHIFT, SPACE"|\
      "$launcher_toggle_binding"|\
      "bind = SUPER CTRL SHIFT, SPACE, exec, qs -c bar ipc call themeSwitcher toggle"|\
      "unbind = SUPER CTRL, SPACE"|\
      "bindd = SUPER CTRL, SPACE, Quickshell wallpaper switcher, exec, qs -c bar ipc call -- wallpaperSwitcher toggle"|\
      "bindd = SUPER CTRL, SPACE, Wallpaper picker, exec, qs -c bar ipc call picker wallpaper"|\
      "bindd = SUPER SHIFT, SPACE, Refresh Quickshell bar, exec, bash -lc 'qs -c bar kill; sleep 0.2; qs -n -d -c bar'"|\
      "bindd = SUPER SHIFT, SPACE, Toggle-refresh Quickshell bar, exec, bash -lc 'qs -c bar kill >/dev/null 2>&1 || true; sleep 0.35; qs -n -d -c bar'"|\
      "bindd = SUPER SHIFT, SPACE, Toggle Quickshell bar, exec, bash -lc 'if qs list --all 2>/dev/null | grep -q \"$HOME/.config/quickshell/bar/shell.qml\"; then qs -c bar kill >/dev/null 2>&1 || true; else qs -n -d -c bar; fi'")
        removed=1
        ;;
      *)
        printf '%s\n' "$line" >> "$tmp"
        ;;
    esac
  done < "$keybindings"

  if [[ "$removed" -eq 1 ]]; then
    if grep -q '[^[:space:]]' "$tmp"; then
      mv "$tmp" "$keybindings"
    else
      rm -f "$tmp" "$keybindings"
    fi
    info "Removed Hyprland Quickshell bindings"
  else
    rm -f "$tmp"
  fi
}

remove_hypr_switcher_blur_rules() {
  local looknfeel="${HYPR_LOOKNFEEL_CONF:-$HOME/.config/hypr/looknfeel.conf}"
  [[ -f "$looknfeel" ]] || return 0

  local tmp removed=0 in_block=0
  tmp="$(mktemp)"
  while IFS= read -r line || [[ -n "$line" ]]; do
    if [[ "$line" == "# >>> quickshell-rise managed switcher blur rules >>>" ]]; then
      in_block=1
      removed=1
      continue
    fi
    if [[ "$line" == "# <<< quickshell-rise managed switcher blur rules <<<" ]]; then
      in_block=0
      continue
    fi
    [[ "$in_block" -eq 1 ]] && continue
    printf '%s\n' "$line" >> "$tmp"
  done < "$looknfeel"

  if [[ "$removed" -eq 1 ]]; then
    if grep -q '[^[:space:]]' "$tmp"; then
      mv "$tmp" "$looknfeel"
    else
      rm -f "$tmp" "$looknfeel"
    fi
    info "Removed Hyprland Quickshell switcher blur rules"
  else
    rm -f "$tmp"
  fi
}

remove_hypr_quickshell_bindings
remove_hypr_switcher_blur_rules

if compgen -G "$unitdir/claude-usage*" >/dev/null 2>&1 || compgen -G "$bindir/claude-usage*" >/dev/null 2>&1; then
  # stop + disable timers AND services (covers a oneshot run that's mid-flight)
  systemctl --user disable --now \
    claude-usage.timer claude-usage-cookie.timer claude-usage-calc.timer >/dev/null 2>&1 || true
  systemctl --user stop \
    claude-usage.service claude-usage-cookie.service claude-usage-calc.service >/dev/null 2>&1 || true
  rm -f "$unitdir"/claude-usage.service       "$unitdir"/claude-usage.timer \
        "$unitdir"/claude-usage-calc.service   "$unitdir"/claude-usage-calc.timer \
        "$unitdir"/claude-usage-cookie.service "$unitdir"/claude-usage-cookie.timer
  rm -f "$bindir"/claude-usage "$bindir"/claude-usage-calc "$bindir"/claude-usage-cookie
  rm -f "$HOME/.cache/claude-usage.json" "$HOME/.cache/claude-usage-api.json" \
        "$HOME/.cache/claude-usage-skip" "$HOME/.cache/claude-usage-notified" \
        "$HOME/.cache/claude-usage-calibration.json"
  systemctl --user daemon-reload >/dev/null 2>&1 || true
  systemctl --user reset-failed 'claude-usage*' >/dev/null 2>&1 || true   # clear any ghost state
  # belt-and-suspenders: kill any lingering process (there shouldn't be one)
  pkill -f "$bindir/claude-usage" 2>/dev/null || true
  info "Removed Claude usage backend (script, timer, cache; nothing left running)"
fi

# 1b2. remove the Codex usage backend, if it was installed (idempotent).
# Pairs with the AI usage widget's Codex side (install_codex_backend in install.sh).
if compgen -G "$unitdir/codex-usage*" >/dev/null 2>&1 || compgen -G "$bindir/codex-usage*" >/dev/null 2>&1; then
  systemctl --user disable --now codex-usage.timer >/dev/null 2>&1 || true
  systemctl --user stop codex-usage.service >/dev/null 2>&1 || true
  rm -f "$unitdir"/codex-usage.service "$unitdir"/codex-usage.timer
  rm -f "$bindir"/codex-usage
  rm -f "$HOME/.cache/codex-usage.json"
  systemctl --user daemon-reload >/dev/null 2>&1 || true
  systemctl --user reset-failed 'codex-usage*' >/dev/null 2>&1 || true   # clear any ghost state
  pkill -f "$bindir/codex-usage" 2>/dev/null || true
  info "Removed Codex usage backend (script, timer, cache; nothing left running)"
fi

# 1b3. remove the OpenCode usage backend, if it was installed (idempotent).
if compgen -G "$unitdir/opencode-usage*" >/dev/null 2>&1 || compgen -G "$bindir/opencode-usage*" >/dev/null 2>&1; then
  systemctl --user disable --now opencode-usage.timer >/dev/null 2>&1 || true
  systemctl --user stop opencode-usage.service >/dev/null 2>&1 || true
  rm -f "$unitdir"/opencode-usage.service "$unitdir"/opencode-usage.timer
  rm -f "$bindir"/opencode-usage
  rm -f "$HOME/.cache/opencode-usage.json"
  systemctl --user daemon-reload >/dev/null 2>&1 || true
  systemctl --user reset-failed 'opencode-usage*' >/dev/null 2>&1 || true
  pkill -f "$bindir/opencode-usage" 2>/dev/null || true
  info "Removed OpenCode usage backend (script, timer, cache; nothing left running)"
fi

# 1c. remove the shell self-updater, if installed (idempotent).
qsbindir="$HOME/.config/quickshell/bin"
if compgen -G "$unitdir/qs-shell-update-check.*" >/dev/null 2>&1 || [[ -e "$qsbindir/qs-shell-check-update.sh" ]]; then
  systemctl --user disable --now qs-shell-update-check.timer >/dev/null 2>&1 || true
  systemctl --user stop qs-shell-update-check.service >/dev/null 2>&1 || true
  rm -f "$unitdir"/qs-shell-update-check.service "$unitdir"/qs-shell-update-check.timer
  rm -f "$qsbindir"/qs-shell-check-update.sh \
        "$qsbindir"/qs-shell-apply-update.sh \
        "$qsbindir"/qs-shell-refresh-local.sh \
        "$qsbindir"/ensure-hypr-launcher-binding.sh \
        "$qsbindir"/ensure-hypr-switcher-blur-rules.sh
  rm -rf "$HOME/.cache/qs-shell" "$HOME/.local/share/quickshell-dots" \
         "${XDG_STATE_HOME:-$HOME/.local/state}/qs-shell"
  systemctl --user daemon-reload >/dev/null 2>&1 || true
  systemctl --user reset-failed 'qs-shell-update-check*' >/dev/null 2>&1 || true
  info "Removed shell self-updater (scripts, timer, cache, updater clone)"
fi

# 1c.1 remove files from the retired package-updater feature (idempotent).
rm -f "$qsbindir"/qs-package-update-state.sh \
      "$qsbindir"/qs-topgrade-update.sh \
      "$qsbindir"/qs-theme-update-check.sh \
      "$HOME/.cache/qs-theme-updates.json" \
      "$HOME/.cache/qs-theme-update.lock" \
      "${XDG_STATE_HOME:-$HOME/.local/state}/quickshell/package-update-state" \
      "${XDG_STATE_HOME:-$HOME/.local/state}/quickshell/package-update-state.lock"

# 1c.2 remove the reversible UI mode switcher and its project-owned state.
if [[ -e "$HOME/.local/bin/qs-mode" || -e "${XDG_STATE_HOME:-$HOME/.local/state}/qs-rise/mode" ]]; then
  rm -f "$HOME/.local/bin/qs-mode" "${XDG_STATE_HOME:-$HOME/.local/state}/qs-rise/mode"
  info "Removed reversible UI mode switcher"
fi
rm -f "$HOME/.local/bin/qs-rise-input" "$HOME/.local/bin/qs-menu-action" "$HOME/.local/bin/qs-menu-data" "$HOME/.local/bin/qs-theme-switcher" "$HOME/.local/bin/qs-wallpaper-switcher" "$HOME/.local/bin/qs-clipboard" "$HOME/.local/bin/qs-emoji" "$HOME/.local/bin/qs-capture" "$HOME/.local/bin/qs-notification-silence" "${XDG_STATE_HOME:-$HOME/.local/state}/qs-rise/notifications-silenced"
rm -f "$HOME/.config/systemd/user/elephant.service.d/50-qs-rise-clipboard-privacy.conf" \
      "$HOME/.local/lib/qs-rise/elephant-bin/wl-paste" \
      "$HOME/.local/lib/qs-rise/qs-clipboard-filter.py"
rmdir "$HOME/.config/systemd/user/elephant.service.d" "$HOME/.local/lib/qs-rise/elephant-bin" "$HOME/.local/lib/qs-rise" 2>/dev/null || true
systemctl --user daemon-reload >/dev/null 2>&1 || true
if [[ -f "${XDG_STATE_HOME:-$HOME/.local/state}/qs-rise/elephant-service-enabled-by-installer" ]]; then
  elephant service disable >/dev/null 2>&1 || true
  rm -f "${XDG_STATE_HOME:-$HOME/.local/state}/qs-rise/elephant-service-enabled-by-installer"
else
  systemctl --user try-restart elephant.service >/dev/null 2>&1 || true
fi
if [[ -f "$HOME/.local/bin/swayosd-client" ]] && grep -q 'quickshell-rise-owned-swayosd-client' "$HOME/.local/bin/swayosd-client"; then rm -f "$HOME/.local/bin/swayosd-client"; fi
rm -rf "${XDG_CACHE_HOME:-$HOME/.cache}/quickshell-theme-switcher"
rm -rf "${XDG_CACHE_HOME:-$HOME/.cache}/quickshell-wallpaper-switcher"
rm -rf "${XDG_CACHE_HOME:-$HOME/.cache}/quickshell-history-thumbs"
rm -f "${XDG_RUNTIME_DIR:-/tmp}/qs-rise-osd.json"
rm -f "${XDG_CACHE_HOME:-$HOME/.cache}/qs-rise-notifications.json"
systemctl --user unmask swayosd-server.service >/dev/null 2>&1 || true
systemctl --user enable --now swayosd-server.service >/dev/null 2>&1 || true
if command -v mako >/dev/null 2>&1 && ! pgrep -x mako >/dev/null 2>&1; then setsid mako >/dev/null 2>&1 < /dev/null & fi
rmdir "${XDG_STATE_HOME:-$HOME/.local/state}/qs-rise" 2>/dev/null || true

# 1d. remove the ArchUpdater security gate (script, fetch timer, list)
if [[ -f "$bindir/qs-arch-security-gate.sh" || -f "$bindir/qs-aur-blacklist-fetch.sh" \
      || -f "$unitdir/qs-aur-blacklist-fetch.service" || -f "$unitdir/qs-aur-blacklist-fetch.timer" ]]; then
  systemctl --user disable --now qs-aur-blacklist-fetch.timer >/dev/null 2>&1 || true
  systemctl --user stop qs-aur-blacklist-fetch.service >/dev/null 2>&1 || true
  rm -f "$unitdir"/qs-aur-blacklist-fetch.service "$unitdir"/qs-aur-blacklist-fetch.timer
  rm -f "$bindir"/qs-arch-security-gate.sh "$bindir"/qs-aur-blacklist-fetch.sh
  # generated artifacts (cache, regenerated by the fetcher) — safe to remove
  rm -f "$HOME/.local/share/qs-aur-blacklist.txt" \
        "$HOME/.local/share/qs-aur-blacklist.txt.meta.json" \
        "$HOME/.local/share/qs-aur-blacklist.txt.pending"
  # the supplement is user-editable (ad-hoc additions survive refreshes) — keep it
  if [[ -f "$HOME/.local/share/qs-aur-blacklist.local.txt" ]]; then
    info "Kept blacklist supplement (qs-aur-blacklist.local.txt) — delete it manually to purge"
  fi
  systemctl --user daemon-reload >/dev/null 2>&1 || true
  systemctl --user reset-failed 'qs-aur-blacklist-fetch*' >/dev/null 2>&1 || true
  info "Removed ArchUpdater security gate (script, fetch timer, list)"
fi

# 2. remove the post-boot hook (if the user installed it)
boot="$HOME/.config/omarchy/hooks/post-boot.d/quickshell-rise"
[[ -f "$boot" ]] && { rm -f "$boot"; info "Removed post-boot hook"; }

# 3. remove the theme hook we installed
hook="$HOME/.config/omarchy/hooks/theme-set.d/50-quickshell-bar.sh"
[[ -f "$hook" ]] && { rm -f "$hook"; info "Removed theme hook"; }

# 4. remove the config — restore the most recent backup if one exists.
# Optional status widgets and their information popups (including Tailscale)
# live only inside this owned tree; uninstalling them must never change their
# underlying system services.
# (ownership already verified at the top: $DEST is ours, or does not exist)
restored=false
if [[ -d "$DEST" ]]; then
  rm -rf "$DEST"
  latest="$(ls -dt "$DEST".bak.* 2>/dev/null | head -1 || true)"
  if [[ -n "${latest:-}" ]]; then
    mv "$latest" "$DEST"
    info "Restored previous config from backup ($(basename "$latest"))"
    restored=true
  else
    info "Removed $DEST"
  fi
else
  warn "Nothing installed at $DEST"
fi

# 4b. remove saved bar settings (widget toggles, splits, slot order)
if compgen -G "$HOME/.cache/quickshell_*" >/dev/null 2>&1; then
  rm -f "$HOME/.cache/quickshell_widgets" "$HOME/.cache/quickshell_splits" \
        "$HOME/.cache/quickshell_barorder" "$HOME/.cache/quickshell_barsplits"
  info "Removed saved bar settings (widget toggles, splits, slot order)"
fi

# 5. restart the bar that was in use before install
if [[ "$restored" == true ]] && [[ -f "$DEST/shell.qml" ]]; then
  setsid quickshell -p "$DEST" >/dev/null 2>&1 & disown
  info "Restarted quickshell from backup"
else
  if command -v omarchy &>/dev/null; then
    omarchy restart waybar 2>/dev/null && info "Restarted waybar" || true
  else
    setsid waybar >/dev/null 2>&1 & disown 2>/dev/null || true
    info "Restarted waybar"
  fi
fi

info "Uninstalled.${c_0}  (older backups under ~/.config/quickshell/bar.bak.* are kept)"
