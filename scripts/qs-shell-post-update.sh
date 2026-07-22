#!/usr/bin/env bash
# QS-Shell post-update hook.
#
# Called by qs-shell-apply-update.sh after every successful shell update, with
# the repo root as $1. Installs/refreshes the companion pieces that live
# OUTSIDE the bar config dir — helper scripts and systemd user units — so a
# bar update is complete on its own and never needs a manual install.sh re-run.
#
# Idempotent and defensive: a missing source file is skipped, a failing step
# warns the caller via exit code but must never break the already-applied
# update. Opt-in AI backends are refreshed only when installed or discoverable.
set -uo pipefail

repo="${1:-${QS_SHELL_REPO:-$HOME/.local/share/quickshell-dots}}"
bin="$HOME/.local/bin"
qsbin="$HOME/.config/quickshell/bin"
units="$HOME/.config/systemd/user"

# install via temp + rename: the target gets a NEW inode, so replacing a script
# that is currently executing (e.g. the apply script calling us) is safe.
put() { # src dst mode
  local src="$1" dst="$2" mode="$3" t
  [ -f "$src" ] || return 0
  t="$(mktemp "$dst.XXXXXX")" || return 1
  cp "$src" "$t" && chmod "$mode" "$t" && mv -f "$t" "$dst" || { rm -f "$t"; return 1; }
}

rc=0
mkdir -p "$bin" "$qsbin" "$units"

# Remove runtime artifacts from the retired package-updater feature.
systemctl --user disable --now qs-aur-blacklist-fetch.timer >/dev/null 2>&1 || true
systemctl --user stop qs-aur-blacklist-fetch.service >/dev/null 2>&1 || true
rm -f "$units/qs-aur-blacklist-fetch.service" "$units/qs-aur-blacklist-fetch.timer"
rm -f "$qsbin/qs-package-update-state.sh" "$qsbin/qs-topgrade-update.sh" \
      "$qsbin/qs-theme-update-check.sh"
rm -f "$bin/qs-arch-security-gate.sh" "$bin/qs-aur-blacklist-fetch.sh"
rm -f "$HOME/.cache/qs-theme-updates.json" "$HOME/.cache/qs-theme-update.lock"
rm -f "${XDG_STATE_HOME:-$HOME/.local/state}/quickshell/package-update-state" \
      "${XDG_STATE_HOME:-$HOME/.local/state}/quickshell/package-update-state.lock"
rm -f "$HOME/.local/share/qs-aur-blacklist.txt" \
      "$HOME/.local/share/qs-aur-blacklist.txt.meta.json" \
      "$HOME/.local/share/qs-aur-blacklist.txt.pending"

# ── keep the updater itself current (check + apply + this hook) ─
put "$repo/scripts/qs-shell-check-update.sh" "$qsbin/qs-shell-check-update.sh" 755 || rc=1
put "$repo/scripts/qs-shell-apply-update.sh" "$qsbin/qs-shell-apply-update.sh" 755 || rc=1
put "$repo/scripts/qs-shell-refresh-local.sh" "$qsbin/qs-shell-refresh-local.sh" 755 || rc=1
put "$repo/scripts/qs-menu-data.sh" "$bin/qs-menu-data" 755 || rc=1
put "$repo/scripts/ensure-hypr-launcher-binding.sh" "$qsbin/ensure-hypr-launcher-binding.sh" 755 || rc=1
put "$repo/scripts/ensure-hypr-switcher-blur-rules.sh" "$qsbin/ensure-hypr-switcher-blur-rules.sh" 755 || rc=1
put "$repo/systemd/qs-shell-update-check.service" "$units/qs-shell-update-check.service" 644 || rc=1
put "$repo/systemd/qs-shell-update-check.timer"   "$units/qs-shell-update-check.timer"   644 || rc=1

if [ -f "$repo/scripts/ensure-hypr-launcher-binding.sh" ]; then
  bash "$repo/scripts/ensure-hypr-launcher-binding.sh" || rc=1
fi
if [ -f "$repo/scripts/ensure-hypr-switcher-blur-rules.sh" ]; then
  bash "$repo/scripts/ensure-hypr-switcher-blur-rules.sh" || rc=1
fi

# Re-arm the timer so refreshed unit files take effect now. Plain
# enable --now is a no-op on an already-active timer, and a daemon-reload
# alone can leave a monotonic timer "elapsed" with no next trigger.
systemctl --user daemon-reload >/dev/null 2>&1 || true
systemctl --user enable --now qs-shell-update-check.timer >/dev/null 2>&1 || true
systemctl --user try-restart qs-shell-update-check.timer >/dev/null 2>&1 || true

# ── opt-in components: refresh only if the user installed them ──
if [ -x "$bin/claude-usage" ]; then
  put "$repo/scripts/claude-usage" "$bin/claude-usage" 755 || rc=1
  put "$repo/systemd/claude-usage.service" "$units/claude-usage.service" 644 || rc=1
  put "$repo/systemd/claude-usage.timer"   "$units/claude-usage.timer"   644 || rc=1
fi
if [ -x "$bin/codex-usage" ]; then
  put "$repo/scripts/codex-usage" "$bin/codex-usage" 755 || rc=1
  put "$repo/systemd/codex-usage.service" "$units/codex-usage.service" 644 || rc=1
  put "$repo/systemd/codex-usage.timer"   "$units/codex-usage.timer"   644 || rc=1
fi
ai_backend_installed=0
if [ -x "$bin/claude-usage" ] || [ -x "$bin/codex-usage" ] || [ -x "$bin/opencode-usage" ]; then
  ai_backend_installed=1
fi
opencode_available=0
if command -v opencode >/dev/null 2>&1 || [ -e "$HOME/.local/share/opencode/opencode.db" ]; then
  opencode_available=1
fi
if [ -x "$bin/opencode-usage" ] || { [ "$ai_backend_installed" -eq 1 ] && [ "$opencode_available" -eq 1 ]; }; then
  put "$repo/scripts/opencode-usage" "$bin/opencode-usage" 755 || rc=1
  put "$repo/systemd/opencode-usage.service" "$units/opencode-usage.service" 644 || rc=1
  put "$repo/systemd/opencode-usage.timer"   "$units/opencode-usage.timer"   644 || rc=1
fi

if [ "$ai_backend_installed" -eq 1 ]; then
  ai_timers=""
  [ -f "$units/claude-usage.timer" ] && ai_timers="$ai_timers claude-usage.timer"
  [ -f "$units/codex-usage.timer" ] && ai_timers="$ai_timers codex-usage.timer"
  [ -f "$units/opencode-usage.timer" ] && ai_timers="$ai_timers opencode-usage.timer"
  systemctl --user daemon-reload >/dev/null 2>&1 || true
  if [ -n "$ai_timers" ]; then
    # shellcheck disable=SC2086
    systemctl --user enable --now $ai_timers >/dev/null 2>&1 || true
    # shellcheck disable=SC2086
    systemctl --user try-restart $ai_timers >/dev/null 2>&1 || true
  fi
fi

exit "$rc"
