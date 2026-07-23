#!/usr/bin/env bash
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
real_home="${HOME:?HOME must be set}"
tmp="$(mktemp -d)"
trap 'rm -rf -- "$tmp"' EXIT

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
export HOME="$tmp/home"
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_CACHE_HOME="$HOME/.cache"
export XDG_STATE_HOME="$HOME/.local/state"
export XDG_RUNTIME_DIR="$tmp/runtime"
export HYPR_BINDINGS_CONF="$XDG_CONFIG_HOME/hypr/bindings.conf"
export HYPR_LOOKNFEEL_CONF="$XDG_CONFIG_HOME/hypr/looknfeel.conf"
export QS_TEST_COMMAND_LOG="$tmp/commands.log"
mkdir -p "$HOME" "$XDG_RUNTIME_DIR" "$tmp/bin"
: > "$QS_TEST_COMMAND_LOG"

[[ "$(realpath -m "$HOME")" != "$(realpath -m "$real_home")" ]] || fail "temporary HOME resolves to real HOME"
[[ "$HYPR_BINDINGS_CONF" == "$tmp"/* ]] || fail "bindings escaped fixture"
mkdir -p "$(dirname "$HYPR_BINDINGS_CONF")"
printf 'user = preserved\n' > "$HYPR_BINDINGS_CONF"

cat > "$tmp/bin/qs" <<'SHIM'
#!/usr/bin/env bash
printf 'qs\t%s\n' "$*" >> "${QS_TEST_COMMAND_LOG:?}"
case "$*" in
  'list -c bar -j') printf '[]\n' ;;
  'list --all') printf '%s\n' "$HOME/.config/quickshell/bar/shell.qml" ;;
  *'ipc call health ping') exit 0 ;;
esac
SHIM
chmod +x "$tmp/bin/qs"

cat > "$tmp/bin/git" <<'SHIM'
#!/usr/bin/env bash
printf 'git\t%s\n' "$*" >> "${QS_TEST_COMMAND_LOG:?}"
if [[ " $* " == *' clone '* ]]; then
  destination="${@: -1}"
  mkdir -p "$destination/.git"
fi
exit 0
SHIM
chmod +x "$tmp/bin/git"

for command in systemctl hyprctl pkill setsid omarchy waybar mako swayosd-server walker notify-send curl; do
  cat > "$tmp/bin/$command" <<'SHIM'
#!/usr/bin/env bash
printf '%s\t%s\n' "${0##*/}" "$*" >> "${QS_TEST_COMMAND_LOG:?}"
[[ "${0##*/}" == pkill ]] && exit 1
exit 0
SHIM
  chmod +x "$tmp/bin/$command"
done
cat > "$tmp/bin/fc-list" <<'SHIM'
#!/usr/bin/env bash
printf '%s\n' 'JetBrainsMono Nerd Font' 'Material Symbols Rounded'
SHIM
cat > "$tmp/bin/sleep" <<'SHIM'
#!/usr/bin/env bash
exit 0
SHIM
chmod +x "$tmp/bin/fc-list" "$tmp/bin/sleep"
export PATH="$tmp/bin:/usr/bin:/bin"

mkdir -p "$HOME/.local/bin"
printf 'foreign compatibility wrapper\n' > "$HOME/.local/bin/swayosd-client"
if bash "$repo/install.sh" --no-ai-backend --no-autostart >/dev/null 2>&1; then
  fail "installer overwrote a foreign swayosd-client"
fi
[[ "$(cat "$HOME/.local/bin/swayosd-client")" == 'foreign compatibility wrapper' ]] || fail "foreign wrapper changed"
rm -f "$HOME/.local/bin/swayosd-client"

bash "$repo/install.sh" --no-ai-backend --no-autostart >/dev/null
destination="$HOME/.config/quickshell/bar"
[[ -f "$destination/.qsrise" ]] || fail "ownership marker missing"
[[ "$(cat "$destination/.qsrise-source")" == "$repo" ]] || fail "source marker mismatch"
bash "$repo/scripts/qs-verify-config-tree.sh" "$repo/versions/default" "$destination"
[[ "$(cat "$XDG_STATE_HOME/qs-rise/mode")" == quickshell ]] || fail "healthy install did not record quickshell"

printf 'fixture custom quote\n' > "$destination/quotes.txt"
bash "$repo/install.sh" --no-ai-backend --no-autostart >/dev/null
[[ "$(cat "$destination/quotes.txt")" == 'fixture custom quote' ]] || fail "repeat install lost custom quotes"
bash "$repo/scripts/qs-verify-config-tree.sh" "$repo/versions/default" "$destination"

for marker in \
  '# >>> quickshell-rise managed menu bindings >>>' \
  '# >>> quickshell-rise managed media bindings >>>' \
  '# >>> quickshell-rise managed notification bindings >>>'; do
  [[ "$(grep -Fxc "$marker" "$HYPR_BINDINGS_CONF")" -eq 1 ]] || fail "managed marker is not idempotent: $marker"
done
grep -q '^systemctl[[:space:]]' "$QS_TEST_COMMAND_LOG" || fail "systemctl was not intercepted"
grep -q '^qs[[:space:]].*ipc call health ping' "$QS_TEST_COMMAND_LOG" || fail "health check was not exercised"
[[ ! -e "$HOME/.config/omarchy/hooks/post-boot.d/quickshell-rise" ]] || fail "--no-autostart installed hook"

bash "$repo/install.sh" --no-ai-backend --autostart >/dev/null
cmp -s "$repo/contrib/post-boot.d/quickshell-rise" \
  "$HOME/.config/omarchy/hooks/post-boot.d/quickshell-rise" || fail "autostart policy did not install source"
bash "$repo/install.sh" --no-ai-backend --no-autostart >/dev/null
[[ ! -e "$HOME/.config/omarchy/hooks/post-boot.d/quickshell-rise" ]] || fail "--no-autostart did not remove hook"

# Exercise complete cleanup and backup restoration without touching live state.
backup="$destination.bak.20000101-000000"
mkdir -p "$backup" "$HOME/.local/share"
printf '// previous user config\n' > "$backup/shell.qml"
printf 'user supplement\n' > "$HOME/.local/share/qs-aur-blacklist.local.txt"
printf 'unrelated user helper\n' > "$HOME/.local/bin/user-helper"

source "$repo/scripts/qs-artifact-manifest.sh"
artifact_paths="$tmp/artifact-paths"
record_artifact() {
  qs_artifact_destination "$HOME" "$2" >> "$artifact_paths"
}
for policy in mandatory foreign-guarded optional-existing optional-ai optional-ai-claude optional-ai-codex optional-ai-opencode; do
  qs_artifacts_each "$repo/scripts/qs-owned-artifacts.tsv" "$policy" record_artifact
done

bash "$repo/uninstall.sh" >/dev/null
[[ "$(cat "$destination/shell.qml")" == '// previous user config' ]] || fail "uninstall did not restore prior config"
[[ ! -e "$destination/.qsrise" ]] || fail "restored config retained project marker"
while IFS= read -r artifact; do
  [[ ! -e "$artifact" ]] || fail "owned artifact survived uninstall: $artifact"
done < "$artifact_paths"
[[ "$(cat "$HOME/.local/share/qs-aur-blacklist.local.txt")" == 'user supplement' ]] || fail "user blacklist supplement changed"
[[ "$(cat "$HOME/.local/bin/user-helper")" == 'unrelated user helper' ]] || fail "unrelated helper changed"
grep -Fqx 'user = preserved' "$HYPR_BINDINGS_CONF" || fail "uninstall lost user binding content"
grep -q '^setsid[[:space:]].*quickshell -p .*bar' "$QS_TEST_COMMAND_LOG" || fail "restored config restart was not intercepted"

printf 'ok (full isolated repeat install/uninstall lifecycle)\n'
