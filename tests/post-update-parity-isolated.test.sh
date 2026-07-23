#!/usr/bin/env bash
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
real_home="${HOME:?HOME must be set}"
tmp="$(mktemp -d)"
trap 'rm -rf -- "$tmp"' EXIT

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
assert_same() { cmp -s "$1" "$2" || fail "$2 does not match ${1#$repo/}"; }

export HOME="$tmp/home"
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_CACHE_HOME="$HOME/.cache"
export XDG_STATE_HOME="$HOME/.local/state"
export XDG_RUNTIME_DIR="$tmp/runtime"
export HYPR_BINDINGS_CONF="$XDG_CONFIG_HOME/hypr/bindings.conf"
export HYPR_LOOKNFEEL_CONF="$XDG_CONFIG_HOME/hypr/looknfeel.conf"
export QS_TEST_COMMAND_LOG="$tmp/commands.log"
mkdir -p "$HOME/.local/bin" "$HOME/.config/quickshell/bin" "$HOME/.config/systemd/user" \
  "$HOME/.config/omarchy/hooks/theme-set.d" "$HOME/.config/omarchy/hooks/post-boot.d" \
  "$HOME/.config/hypr" "$XDG_STATE_HOME/qs-rise" "$HOME/.local/lib/qs-rise/elephant-bin" "$XDG_RUNTIME_DIR" "$tmp/bin"

[[ "$(realpath -m "$HOME")" != "$(realpath -m "$real_home")" ]] || fail "temporary HOME resolves to real HOME"
[[ "$(realpath -m "$HYPR_BINDINGS_CONF")" != "$(realpath -m "$real_home/.config/hypr/bindings.conf")" ]] || fail "binding target resolves to real configuration"

for command in systemctl hyprctl qs quickshell waybar mako swayosd-server walker omarchy pkill notify-send; do
  cat > "$tmp/bin/$command" <<'SHIM'
#!/usr/bin/env bash
printf '%s\t%s\n' "${0##*/}" "$*" >> "${QS_TEST_COMMAND_LOG:?}"
exit 0
SHIM
  chmod +x "$tmp/bin/$command"
done
export PATH="$tmp/bin:/usr/bin:/bin"

# Seed files as stale but project-owned. The optional post-boot hook is refreshed
# only because it already exists.
printf '# quickshell-rise-owned-swayosd-client\nstale\n' > "$HOME/.local/bin/swayosd-client"
for backend in claude-usage codex-usage opencode-usage; do
  printf '#!/usr/bin/env bash\n# stale optional backend\n' > "$HOME/.local/bin/$backend"
  chmod +x "$HOME/.local/bin/$backend"
done
printf 'stale\n' > "$HOME/.config/omarchy/hooks/post-boot.d/quickshell-rise"
printf 'user = kept\n' > "$HYPR_BINDINGS_CONF"
printf 'decoration { rounding = 7 }\n' > "$HYPR_LOOKNFEEL_CONF"
printf 'omarchy\n' > "$XDG_STATE_HOME/qs-rise/mode"

bash "$repo/scripts/qs-shell-post-update.sh" "$repo"

while IFS='|' read -r source destination; do
  assert_same "$repo/$source" "$HOME/$destination"
done <<'EOF'
scripts/qs-mode.sh|.local/bin/qs-mode
scripts/qs-managed-bindings.sh|.local/bin/qs-managed-bindings
scripts/qs-rise-input.sh|.local/bin/qs-rise-input
scripts/swayosd-client|.local/bin/swayosd-client
scripts/qs-menu-action.sh|.local/bin/qs-menu-action
scripts/qs-menu-data.sh|.local/bin/qs-menu-data
scripts/qs-theme-switcher|.local/bin/qs-theme-switcher
scripts/qs-wallpaper-switcher|.local/bin/qs-wallpaper-switcher
scripts/qs-clipboard.sh|.local/bin/qs-clipboard
scripts/qs-emoji.sh|.local/bin/qs-emoji
scripts/qs-capture.sh|.local/bin/qs-capture
scripts/qs-notification-silence.sh|.local/bin/qs-notification-silence
scripts/qs-state-write|.local/bin/qs-state-write
scripts/qs_usage_cache.py|.local/bin/qs_usage_cache.py
scripts/claude-usage|.local/bin/claude-usage
systemd/claude-usage.service|.config/systemd/user/claude-usage.service
systemd/claude-usage.timer|.config/systemd/user/claude-usage.timer
scripts/codex-usage|.local/bin/codex-usage
systemd/codex-usage.service|.config/systemd/user/codex-usage.service
systemd/codex-usage.timer|.config/systemd/user/codex-usage.timer
scripts/opencode-usage|.local/bin/opencode-usage
systemd/opencode-usage.service|.config/systemd/user/opencode-usage.service
systemd/opencode-usage.timer|.config/systemd/user/opencode-usage.timer
scripts/qs-clipboard-filter.py|.local/lib/qs-rise/qs-clipboard-filter.py
scripts/qs-elephant-wl-paste.sh|.local/lib/qs-rise/elephant-bin/wl-paste
systemd/elephant-clipboard-privacy.conf|.config/systemd/user/elephant.service.d/50-qs-rise-clipboard-privacy.conf
hooks/50-quickshell-bar.sh|.config/omarchy/hooks/theme-set.d/50-quickshell-bar.sh
contrib/post-boot.d/quickshell-rise|.config/omarchy/hooks/post-boot.d/quickshell-rise
scripts/qs-shell-check-update.sh|.config/quickshell/bin/qs-shell-check-update.sh
scripts/qs-shell-apply-update.sh|.config/quickshell/bin/qs-shell-apply-update.sh
scripts/qs-shell-refresh-local.sh|.config/quickshell/bin/qs-shell-refresh-local.sh
scripts/ensure-hypr-launcher-binding.sh|.config/quickshell/bin/ensure-hypr-launcher-binding.sh
scripts/ensure-hypr-switcher-blur-rules.sh|.config/quickshell/bin/ensure-hypr-switcher-blur-rules.sh
systemd/qs-shell-update-check.service|.config/systemd/user/qs-shell-update-check.service
systemd/qs-shell-update-check.timer|.config/systemd/user/qs-shell-update-check.timer
EOF

grep -Fqx 'user = kept' "$HYPR_BINDINGS_CONF" || fail "binding refresh lost user content"
grep -Fqx 'bindd = SUPER, SPACE, Launch apps, exec, omarchy-launch-walker' "$HYPR_BINDINGS_CONF" || fail "post-update did not preserve Omarchy binding profile"
! grep -Fqx 'bind = SUPER, SPACE, exec, qs -c bar ipc call -- launcher open' "$HYPR_BINDINGS_CONF" || fail "post-update injected Quickshell launcher into Omarchy profile"
grep -Fqx 'decoration { rounding = 7 }' "$HYPR_LOOKNFEEL_CONF" || fail "blur refresh lost user content"
grep -q '^systemctl[[:space:]].*try-restart elephant.service' "$QS_TEST_COMMAND_LOG" || fail "privacy drop-in restart was not intercepted"

# A foreign compatibility wrapper is never overwritten.
printf 'foreign wrapper\n' > "$HOME/.local/bin/swayosd-client"
bash "$repo/scripts/qs-shell-post-update.sh" "$repo"
[[ "$(cat "$HOME/.local/bin/swayosd-client")" == 'foreign wrapper' ]] || fail "foreign swayosd-client was overwritten"

# Reapplying a Quickshell profile updates bindings without starting services.
printf 'quickshell\n' > "$XDG_STATE_HOME/qs-rise/mode"
bash "$repo/scripts/qs-shell-post-update.sh" "$repo"
grep -Fqx 'bind = SUPER, SPACE, exec, qs -c bar ipc call -- launcher open' "$HYPR_BINDINGS_CONF" || fail "post-update did not preserve Quickshell binding profile"
! grep -Fqx 'bindd = SUPER, SPACE, Launch apps, exec, omarchy-launch-walker' "$HYPR_BINDINGS_CONF" || fail "post-update left Omarchy launcher in Quickshell profile"

# Optional autostart remains absent when the user has not opted in.
rm -f "$HOME/.config/omarchy/hooks/post-boot.d/quickshell-rise"
bash "$repo/scripts/qs-shell-post-update.sh" "$repo"
[[ ! -e "$HOME/.config/omarchy/hooks/post-boot.d/quickshell-rise" ]] || fail "post-update enabled optional autostart"

printf 'ok (isolated complete post-update companion parity)\n'
