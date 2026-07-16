#!/usr/bin/env bash
# Quickshell Rise — one-command installer
# Usage:
#   bash <(curl -fsSL https://raw.githubusercontent.com/sanjyay/quickshell-dots/main/install.sh)
#   bash <(curl -fsSL .../install.sh) --autostart
# Autostart via Omarchy post-boot hook (opt-in).
set -euo pipefail

REPO_URL="https://github.com/sanjyay/quickshell-dots.git"
DEST="$HOME/.config/quickshell/bar"
CONFIG_DIR="default"

# args: optional flags
WANT_AUTOSTART="" # "" = leave unchanged and print hint, "yes" = install hook, "no" = remove hook
WANT_CLAUDE="yes" # AI usage backend installs by default; pass --no-ai-backend to skip
for a in "$@"; do
  case "$a" in
    --autostart)          WANT_AUTOSTART="yes" ;;
    --no-autostart)       WANT_AUTOSTART="no"  ;;
    --claude-backend|--ai-backend)       WANT_CLAUDE="yes" ;;
    --no-claude-backend|--no-ai-backend) WANT_CLAUDE="no"  ;;
    *) warn "Ignoring unknown argument: $a" ;;
  esac
done

c_b=$'\e[1m'; c_g=$'\e[32m'; c_y=$'\e[33m'; c_r=$'\e[31m'; c_0=$'\e[0m'
info() { printf "%s==>%s %s\n" "$c_g" "$c_0" "$*"; }
warn() { printf "%s!!%s %s\n"  "$c_y" "$c_0" "$*"; }
err()  { printf "%s✗%s %s\n"   "$c_r" "$c_0" "$*" >&2; }

# ── claude-usage backend (opt-in AI usage backend) ──────────────
# Installs the script + systemd timer that feed the Claude quota widget.
# It reads the OAuth token Claude Code already stores (~/.claude/.credentials.json)
# and queries the same endpoint that powers Claude Code's `/usage` — no browser,
# no cookie, no extra deps, 0 tokens. Any failure here only warns; it never
# aborts the bar install.
install_claude_backend() {
  local src="$1"                              # repo root (temp clone)
  local bindst="$HOME/.local/bin"
  local unitdst="$HOME/.config/systemd/user"

  command -v python3 >/dev/null 2>&1 || { err "python3 missing — skipping Claude backend"; return 1; }
  [[ -f "$HOME/.claude/.credentials.json" ]] || \
    warn "No Claude Code OAuth credentials yet — run 'claude' and log in; the widget fills once a session has run."

  # migrate away from any older split scripts/units (cookie/calc)
  systemctl --user disable --now claude-usage-cookie.timer claude-usage-calc.timer >/dev/null 2>&1 || true
  rm -f "$unitdst"/claude-usage-cookie.* "$unitdst"/claude-usage-calc.* \
        "$bindst"/claude-usage-cookie "$bindst"/claude-usage-calc

  mkdir -p "$bindst" "$unitdst"
  install -m 755 "$src/scripts/claude-usage"          "$bindst/claude-usage"
  install -m 644 "$src/systemd/claude-usage.service"   "$unitdst/claude-usage.service"
  install -m 644 "$src/systemd/claude-usage.timer"     "$unitdst/claude-usage.timer"

  systemctl --user daemon-reload
  systemctl --user enable --now claude-usage.timer >/dev/null 2>&1 || true
  "$bindst/claude-usage" >/dev/null 2>&1 || true   # prime the cache now

  info "Claude usage backend installed (exact 5h + 7d via Claude Code's own token, 0 tokens)"
}

# ── codex-usage backend (opt-in; pairs with the AI usage widget) ─
# Installs the script + systemd timer that feed the Codex side of the quota
# widget. It reads the authoritative rate limits the Codex CLI exposes over its
# local app-server JSON-RPC (account/rateLimits/read) — no browser, no scraping,
# 0 tokens. Any failure here only warns; it never aborts the bar install.
install_codex_backend() {
  local src="$1"                              # repo root (temp clone)
  local bindst="$HOME/.local/bin"
  local unitdst="$HOME/.config/systemd/user"

  command -v python3 >/dev/null 2>&1 || { err "python3 missing — skipping Codex backend"; return 1; }
  command -v codex   >/dev/null 2>&1 || \
    warn "codex CLI not found in PATH — install it and run 'codex login'; the widget fills once Codex has run."

  mkdir -p "$bindst" "$unitdst"
  install -m 755 "$src/scripts/codex-usage"          "$bindst/codex-usage"
  install -m 644 "$src/systemd/codex-usage.service"   "$unitdst/codex-usage.service"
  install -m 644 "$src/systemd/codex-usage.timer"     "$unitdst/codex-usage.timer"

  systemctl --user daemon-reload
  systemctl --user enable --now codex-usage.timer >/dev/null 2>&1 || true
  "$bindst/codex-usage" >/dev/null 2>&1 || true   # prime the cache now

  info "Codex usage backend installed (5h + weekly via Codex app-server RPC, 0 tokens)"
}

# ── opencode-usage backend (opt-in; pairs with the AI usage widget) ─
# Reads OpenCode's local SQLite usage DB and writes the shared AI usage cache.
# No network calls and no API tokens; if OpenCode has not run yet, the cache
# starts filling once ~/.local/share/opencode/opencode.db exists.
install_opencode_backend() {
  local src="$1"                              # repo root (temp clone)
  local bindst="$HOME/.local/bin"
  local unitdst="$HOME/.config/systemd/user"

  command -v python3 >/dev/null 2>&1 || { err "python3 missing — skipping OpenCode backend"; return 1; }
  if ! command -v opencode >/dev/null 2>&1 && [[ ! -e "$HOME/.local/share/opencode/opencode.db" ]]; then
    warn "opencode not found yet — install/run OpenCode; the widget fills once its local DB exists."
  fi

  mkdir -p "$bindst" "$unitdst"
  install -m 755 "$src/scripts/opencode-usage"          "$bindst/opencode-usage"
  install -m 644 "$src/systemd/opencode-usage.service"   "$unitdst/opencode-usage.service"
  install -m 644 "$src/systemd/opencode-usage.timer"     "$unitdst/opencode-usage.timer"

  systemctl --user daemon-reload
  systemctl --user enable --now opencode-usage.timer >/dev/null 2>&1 || true
  "$bindst/opencode-usage" >/dev/null 2>&1 || true   # prime the cache now

  info "OpenCode usage backend installed (local SQLite, configurable soft caps, 0 tokens)"
}

# ── shell self-updater (the in-bar update badge + apply) ────────
# Installs the check/apply scripts + systemd timer, and keeps a persistent FULL
# clone the updater pulls from (the install clone below is --depth 1, too shallow
# for a correct changelog / behind count). Any failure here only warns; it never
# aborts the bar install.
install_shell_updater() {
  local src="$1"                                   # repo root (temp clone) for the files
  local bindst="$HOME/.config/quickshell/bin"
  local unitdst="$HOME/.config/systemd/user"
  local repodir="$HOME/.local/share/quickshell-dots"

  mkdir -p "$bindst" "$unitdst"
  # This read-only helper does not depend on the persistent updater clone.
  install -m 755 "$src/scripts/qs-package-update-state.sh" "$bindst/qs-package-update-state.sh"

  if [[ -d "$repodir/.git" ]]; then
    git -C "$repodir" fetch --quiet origin || true
  else
    mkdir -p "$(dirname "$repodir")"
    git clone --quiet "$REPO_URL" "$repodir" || { err "Updater clone failed — skipping self-updater"; return 1; }
  fi

  mkdir -p "$bindst" "$unitdst"
  install -m 755 "$src/scripts/qs-shell-check-update.sh" "$bindst/qs-shell-check-update.sh"
  install -m 755 "$src/scripts/qs-shell-apply-update.sh" "$bindst/qs-shell-apply-update.sh"
  install -m 755 "$src/scripts/qs-shell-refresh-local.sh" "$bindst/qs-shell-refresh-local.sh"
  install -m 755 "$src/scripts/ensure-hypr-launcher-binding.sh" "$bindst/ensure-hypr-launcher-binding.sh"
  install -m 644 "$src/systemd/qs-shell-update-check.service" "$unitdst/qs-shell-update-check.service"
  install -m 644 "$src/systemd/qs-shell-update-check.timer"   "$unitdst/qs-shell-update-check.timer"

  systemctl --user daemon-reload
  systemctl --user enable --now qs-shell-update-check.timer >/dev/null 2>&1 || true
  "$bindst/qs-shell-check-update.sh" >/dev/null 2>&1 || true   # prime the state now

  info "Shell self-updater installed (badge appears when this repo has updates)"
}

# ── theme update checker (read-only badge/panel signal) ─────────
# Installs the helper the ArchUpdaterPanel runs on demand. It only checks theme
# remotes and writes ~/.cache/qs-theme-updates.json; actual updates stay delegated
# to Omarchy's visible terminal commands.
install_theme_updater() {
  local src="$1"
  local bindst="$HOME/.config/quickshell/bin"
  local state="$HOME/.cache/qs-theme-updates.json"
  local t

  [[ -f "$src/scripts/qs-theme-update-check.sh" ]] || return 0

  mkdir -p "$bindst"
  install -m 755 "$src/scripts/qs-theme-update-check.sh" "$bindst/qs-theme-update-check.sh"
  if [[ ! -e "$state" ]]; then
    mkdir -p "$(dirname "$state")"
    t="$(mktemp -p "$(dirname "$state")" .qs-theme-updates.XXXXXX)"
    printf '{"checked":"","total":0,"reachable":0,"outdated":0,"localEdits":0,"degraded":false,"currentStale":false,"themes":[]}\n' > "$t"
    mv "$t" "$state"
  fi

  info "Theme update checker installed (panel check uses Omarchy theme repos)"
}

# ── 1. dependencies ─────────────────────────────────────────────
need=(qs git jq curl)
opt=(pamixer brightnessctl powerprofilesctl bluetoothctl iwctl hypridle)
miss=()
for b in "${need[@]}"; do command -v "$b" >/dev/null 2>&1 || miss+=("$b"); done
if ((${#miss[@]})); then
  err "Missing required: ${miss[*]}"
  warn "Install quickshell, git, jq, and curl through your system's normal package-management workflow."
  exit 1
fi
optmiss=()
for b in "${opt[@]}"; do command -v "$b" >/dev/null 2>&1 || optmiss+=("$b"); done
((${#optmiss[@]})) && warn "Optional tools missing (some widgets disabled): ${optmiss[*]}"
fontmiss=()
# capture once: `fc-list | grep -q` can SIGPIPE-fail under `set -o pipefail`
fonts="$(fc-list)"
[[ "$fonts" == *"JetBrainsMono Nerd"* ]] || fontmiss+=("JetBrainsMono Nerd Font")
[[ "$fonts" == *"Material Symbols"*  ]] || fontmiss+=("Material Symbols Rounded")
if ((${#fontmiss[@]})); then
  warn "Missing fonts: ${fontmiss[*]}"
  warn "The bar needs these to display icons correctly; installation is intentionally left to your administrator workflow."
  if [[ "$fonts" != *"JetBrainsMono Nerd"* ]]; then
    warn "JetBrains Mono Nerd Font is missing; install it through your normal administrator workflow."
  fi
  if [[ "$fonts" != *"Material Symbols"* ]]; then
    warn "Material Symbols font is missing; install it through your normal administrator workflow."
  fi
fi

# ── 2. choose install source ────────────────────────────────────
tmp="$(mktemp -d)"
stage=""
restore_src=""
cleanup_install() {
  [[ -n "${stage:-}" && -d "$stage" ]] && rm -rf "$stage"
  if [[ -n "${restore_src:-}" && -d "$restore_src" && ! -e "$DEST" ]]; then
    mv "$restore_src" "$DEST" 2>/dev/null || true
  fi
  rm -rf "$tmp"
}
trap cleanup_install EXIT
src_repo=""
script_path="${BASH_SOURCE[0]:-$0}"
script_dir=""
if [[ -n "$script_path" && -f "$script_path" ]]; then
  script_dir="$(cd "$(dirname "$script_path")" && pwd -P)"
fi
if [[ -n "$script_dir" && -d "$script_dir/versions" ]]; then
  src_repo="$script_dir"
  info "Installing from local checkout → $src_repo"
else
  info "Downloading…"
  git clone --depth 1 "$REPO_URL" "$tmp/repo" >/dev/null 2>&1
  src_repo="$tmp/repo"
fi

source_ref="$src_repo"
if [[ "$src_repo" == "$tmp/repo" ]]; then
  source_ref="$HOME/.local/share/quickshell-dots"
fi

[[ -d "$src_repo/versions/$CONFIG_DIR" ]] || { err "Missing config: versions/$CONFIG_DIR"; exit 1; }

# ── 4. install ──────────────────────────────────────────────────
# back up only a FOREIGN config (no .qsrise marker). Re-installing our own bar
# uses a same-parent stage/rename so custom quotes are never held only in /tmp.
mkdir -p "$(dirname "$DEST")"
# Sweep install stages orphaned by SIGKILL / power loss before creating a new one.
rm -rf "$(dirname "$DEST")"/.qs-install-stage.* 2>/dev/null || true
ts="$(date +%Y%m%d-%H%M%S)"
stage="$(mktemp -d -p "$(dirname "$DEST")" .qs-install-stage.XXXXXX)"
cp -r "$src_repo/versions/$CONFIG_DIR/." "$stage/"
echo "$CONFIG_DIR" > "$stage/.qsrise"
if [[ -d "$src_repo/.git" ]]; then
  printf '%s\n' "$source_ref" > "$stage/.qsrise-source"
fi

if [[ -d "$DEST" ]]; then
  if [[ -e "$DEST/.qsrise" ]]; then
    if [[ -f "$DEST/quotes.txt" ]]; then
      cp -p "$DEST/quotes.txt" "$stage/quotes.txt"
      info "Preserved custom quotes.txt"
    fi
    if [[ -f "$DEST/.qsrise-source" && ! -f "$stage/.qsrise-source" ]]; then
      cp -p "$DEST/.qsrise-source" "$stage/.qsrise-source"
    fi
    restore_src="$DEST.old.$ts"
    mv "$DEST" "$restore_src"
  else
    bak="$DEST.bak.$ts"
    info "Backing up your existing config → $bak"
    mv "$DEST" "$bak"
    restore_src="$bak"
  fi
fi
mv "$stage" "$DEST"
stage=""
if [[ -n "$restore_src" && "$restore_src" == "$DEST.old."* ]]; then
  rm -rf "$restore_src"
fi
restore_src=""
info "Installed Quickshell bar → $DEST"

verify_installed_copy() {
  local rel
  for rel in BarSlot.qml \
             modules/ClockWidget.qml \
             modules/ClaudeWidget.qml \
             modules/ScreenRecordWidget.qml \
             modules/TailscaleWidget.qml \
             panels/TailscalePanel.qml \
             panels/WallpaperSwitcherPanel.qml \
             NotificationManager.qml \
             NotificationToastOverlay.qml \
             HardwareOsdOverlay.qml \
             shell.qml; do
    cmp -s "$src_repo/versions/$CONFIG_DIR/$rel" "$DEST/$rel" || {
      err "Installed $rel does not match $src_repo/versions/$CONFIG_DIR/$rel"
      exit 1
    }
  done
}
verify_installed_copy
info "Verified installed bar matches source tree"

# ── 4b. Hyprland Quickshell bindings ───────────────────────────
if [[ -f "$src_repo/scripts/ensure-hypr-launcher-binding.sh" ]]; then
  bash "$src_repo/scripts/ensure-hypr-launcher-binding.sh" || warn "Hyprland Quickshell binding setup incomplete."
fi

# ── 4b1. reversible UI mode switcher ───────────────────────────
if [[ -f "$src_repo/scripts/qs-mode.sh" ]]; then
  mkdir -p "$HOME/.local/bin" "${XDG_STATE_HOME:-$HOME/.local/state}/qs-rise"
  install -m 755 "$src_repo/scripts/qs-mode.sh" "$HOME/.local/bin/qs-mode"
  install -m 755 "$src_repo/scripts/qs-rise-input.sh" "$HOME/.local/bin/qs-rise-input"
  bridge="$HOME/.local/bin/swayosd-client"
  if [[ -e "$bridge" ]] && ! grep -q 'quickshell-rise-owned-swayosd-client' "$bridge"; then
    err "Refusing to overwrite unrelated $bridge"
    exit 1
  fi
  install -m 755 "$src_repo/scripts/swayosd-client" "$bridge"
  cmp -s "$src_repo/scripts/swayosd-client" "$bridge" || { err "Installed SwayOSD bridge does not match source"; exit 1; }
  install -m 755 "$src_repo/scripts/qs-menu-action.sh" "$HOME/.local/bin/qs-menu-action"
  install -m 755 "$src_repo/scripts/qs-theme-switcher" "$HOME/.local/bin/qs-theme-switcher"
  install -m 755 "$src_repo/scripts/qs-wallpaper-switcher" "$HOME/.local/bin/qs-wallpaper-switcher"
  cmp -s "$src_repo/scripts/qs-wallpaper-switcher" "$HOME/.local/bin/qs-wallpaper-switcher" || { err "Installed qs-wallpaper-switcher does not match source"; exit 1; }
  install -m 755 "$src_repo/scripts/qs-clipboard.sh" "$HOME/.local/bin/qs-clipboard"
  install -m 755 "$src_repo/scripts/qs-capture.sh" "$HOME/.local/bin/qs-capture"
  if [[ ! -e "${XDG_STATE_HOME:-$HOME/.local/state}/qs-rise/mode" ]]; then
    printf 'quickshell\n' > "${XDG_STATE_HOME:-$HOME/.local/state}/qs-rise/mode"
  fi
  info "Installed reversible UI mode switcher (qs-mode quickshell|omarchy|status)"
fi
if [[ -f "$src_repo/scripts/qs-notification-silence.sh" ]]; then
  mkdir -p "$HOME/.local/bin"
  install -m 755 "$src_repo/scripts/qs-notification-silence.sh" "$HOME/.local/bin/qs-notification-silence"
fi

# ── 4a. ArchUpdater security gate (pre-install package verdicts) ─
# Pure bash, no extra deps. The weekly fetch timer keeps the known-infected
# list current; without any list the updater panel fail-closes to
# "protection limited" instead of claiming packages are clean.
if [[ -f "$src_repo/scripts/qs-arch-security-gate.sh" ]]; then
  mkdir -p "$HOME/.local/bin"
  install -m 755 "$src_repo/scripts/qs-arch-security-gate.sh" "$HOME/.local/bin/qs-arch-security-gate.sh"
  if [[ -f "$src_repo/scripts/qs-aur-blacklist-fetch.sh" ]]; then
    install -m 755 "$src_repo/scripts/qs-aur-blacklist-fetch.sh" "$HOME/.local/bin/qs-aur-blacklist-fetch.sh"
    mkdir -p "$HOME/.config/systemd/user"
    install -m 644 "$src_repo/systemd/qs-aur-blacklist-fetch.service" "$HOME/.config/systemd/user/qs-aur-blacklist-fetch.service"
    install -m 644 "$src_repo/systemd/qs-aur-blacklist-fetch.timer"   "$HOME/.config/systemd/user/qs-aur-blacklist-fetch.timer"
    systemctl --user daemon-reload
    systemctl --user enable --now qs-aur-blacklist-fetch.timer >/dev/null 2>&1 || true
    "$HOME/.local/bin/qs-aur-blacklist-fetch.sh" >/dev/null 2>&1 || true   # prime the list now
  fi
  info "ArchUpdater security gate installed (weekly blacklist refresh)"
fi

# ── 4c. Theme update checker (panel "Check themes" helper) ─────
install_theme_updater "$src_repo" || warn "Theme update checker setup incomplete — the bar is fine; the themes tab just cannot scan yet."

# ── 5. theme hook (live color updates on Omarchy theme switch) ──
hookdst="$HOME/.config/omarchy/hooks/theme-set.d"
if [[ -f "$src_repo/hooks/50-quickshell-bar.sh" ]]; then
  mkdir -p "$hookdst"
  install -m 0755 "$src_repo/hooks/50-quickshell-bar.sh" "$hookdst/50-quickshell-bar.sh"
  info "Theme hook installed (bar follows Omarchy themes)"
fi

# ── 6. activate the Quickshell provider stack ──────────────────
if [[ -x "$HOME/.local/bin/qs-mode" ]]; then
  "$HOME/.local/bin/qs-mode" quickshell || warn "Quickshell mode health check failed; Omarchy providers were restored."
else
  pkill -x waybar 2>/dev/null || true
  pkill -f "qs.*-c bar" 2>/dev/null || true
  sleep 0.3
  setsid qs -n -d -c bar >/dev/null 2>&1 < /dev/null &
fi
info "Quickshell UI mode activated — use qs-mode omarchy to restore Omarchy providers."

# ── 6b. shell self-updater (never blocks the bar install) ───────
install_shell_updater "$src_repo" || warn "Self-updater setup incomplete — the bar is fine; the update badge just won't appear."

# ── 7. autostart hook / hint ─────────────────────────────────────
RAW="https://raw.githubusercontent.com/sanjyay/quickshell-dots/main"
autostart_dir="$HOME/.config/omarchy/hooks/post-boot.d"
autostart_hook="$autostart_dir/quickshell-rise"
case "$WANT_AUTOSTART" in
  yes)
    mkdir -p "$autostart_dir"
    install -m 0755 "$src_repo/contrib/post-boot.d/quickshell-rise" "$autostart_hook"
    info "Autostart hook installed → $autostart_hook"
    ;;
  no)
    rm -f "$autostart_hook"
    info "Autostart hook removed → $autostart_hook"
    ;;
  *)
    info "Autostart at login via Omarchy post-boot hook:"
    printf "  ${c_b}curl -fsSL -o %s/quickshell-rise %s/contrib/post-boot.d/quickshell-rise${c_0}\n" \
      "\$HOME/.config/omarchy/hooks/post-boot.d" "$RAW"
    printf "  ${c_b}chmod +x %s/quickshell-rise${c_0}\n" \
      "\$HOME/.config/omarchy/hooks/post-boot.d"
    printf "  ${c_b}rm -f %s/quickshell-rise${c_0}  # to remove\n" \
      "\$HOME/.config/omarchy/hooks/post-boot.d"
    ;;
esac

# ── 8. AI usage backends (enabled by default; never block the bar install) ──
do_claude="$WANT_CLAUDE"
if [[ "$do_claude" == "yes" ]]; then
  install_claude_backend "$src_repo" || warn "Claude backend setup incomplete — the bar is installed and fine; re-run with --ai-backend to retry."
  # Codex side of the same AI usage widget — installed alongside when present.
  if command -v codex >/dev/null 2>&1; then
    install_codex_backend "$src_repo" || warn "Codex backend setup incomplete — re-run with --ai-backend to retry."
  else
    info "Skipped Codex usage backend (codex CLI not found; the bar still shows Claude)."
  fi
  install_opencode_backend "$src_repo" || warn "OpenCode backend setup incomplete — re-run with --ai-backend to retry."
else
  refreshed_ai=0
  [[ -x "$HOME/.local/bin/claude-usage" ]] && { install_claude_backend "$src_repo" || warn "Claude backend refresh incomplete."; refreshed_ai=1; }
  [[ -x "$HOME/.local/bin/codex-usage" ]] && { install_codex_backend "$src_repo" || warn "Codex backend refresh incomplete."; refreshed_ai=1; }
  [[ -x "$HOME/.local/bin/opencode-usage" ]] && { install_opencode_backend "$src_repo" || warn "OpenCode backend refresh incomplete."; refreshed_ai=1; }
  if [[ "$refreshed_ai" -eq 0 ]]; then
    info "Skipped AI usage backend (--no-ai-backend was requested)."
  else
    info "Refreshed already-installed AI usage backend scripts."
  fi
fi

info "${c_b}Done — enjoy!${c_0}"
