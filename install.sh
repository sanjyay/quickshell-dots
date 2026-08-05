#!/usr/bin/env bash
set -Eeuo pipefail

PLUGIN_ID="io.github.sanjyay.quickshell-astra"
LEGACY_PLUGIN_ID="io.github.sanjyay.quickshell-rise"
SCHEMA_VERSION=1
REPO_URL="${QS_ASTRA_REPO_URL:-https://github.com/sanjyay/quickshell-dots.git}"
STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}/quickshell-astra"
STATE_FILE="$STATE_HOME/install-state.json"
LEGACY_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}/quickshell-rise"
LEGACY_STATE_FILE="$LEGACY_STATE_HOME/install-state.json"
PLUGINS_DIR="$HOME/.config/omarchy/plugins"
TARGET="$PLUGINS_DIR/$PLUGIN_ID"
LEGACY_TARGET="$PLUGINS_DIR/$LEGACY_PLUGIN_ID"
SHELL_CONFIG="$HOME/.config/omarchy/shell.json"
BINDINGS="$HOME/.config/hypr/bindings.lua"
BLOCK_BEGIN="-- BEGIN QUICKSHELL-ASTRA MANAGED BLOCK"
BLOCK_END="-- END QUICKSHELL-ASTRA MANAGED BLOCK"
LEGACY_BLOCK_BEGIN="-- BEGIN QUICKSHELL-RISE MANAGED BLOCK"
LEGACY_BLOCK_END="-- END QUICKSHELL-RISE MANAGED BLOCK"
LOOKNFEEL="$HOME/.config/hypr/looknfeel.lua"
BLUR_BLOCK_BEGIN="-- BEGIN QUICKSHELL-ASTRA HISTORY BLUR"
BLUR_BLOCK_END="-- END QUICKSHELL-ASTRA HISTORY BLUR"
LEGACY_BLUR_BLOCK_BEGIN="-- BEGIN QUICKSHELL-RISE HISTORY BLUR"
LEGACY_BLUR_BLOCK_END="-- END QUICKSHELL-RISE HISTORY BLUR"
LEGACY_IDLE_WRAPPER="$HOME/.local/bin/quickshell-astra-idle-toggle"
MPV_WRAPPER="$HOME/.local/bin/mpv"
LEGACY_SCREENRECORD_WRAPPER="$HOME/.local/bin/omarchy-capture-screenrecording"
LEGACY_SCREENRECORD_SHIM_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/quickshell-astra/screenrecord-bin"
UNIT_DIR="$HOME/.config/systemd/user"
HOLIDAY_UPDATE_UNIT="quickshell-astra-holiday-annual-update"
LEGACY_HOLIDAY_UPDATE_UNIT="quickshell-rise-holiday-annual-update"

info() { printf '==> %s\n' "$*"; }
warn() { printf '!! %s\n' "$*" >&2; }
die() { printf 'quickshell-astra: %s\n' "$*" >&2; exit 1; }
have() { command -v "$1" >/dev/null 2>&1; }

for command in git jq lua hyprctl pgrep omarchy omarchy-shell mktemp node npm; do
  have "$command" || die "required Quattro command is unavailable: $command"
done
[[ -n ${OMARCHY_PATH:-} && -f "$OMARCHY_PATH/shell/services/PluginRegistry.qml" ]] ||
  die "Omarchy Quattro plugin architecture was not detected; standalone installation is not supported"
omarchy-shell shell ping >/dev/null ||
  die "the long-lived omarchy-shell is not responding"

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
temp_root="$(mktemp -d "${TMPDIR:-/tmp}/quickshell-astra.install.XXXXXX")"
stage="$temp_root/plugin"
backup_plugin="$temp_root/previous-plugin"
backup_shell="$temp_root/shell.json"
backup_bindings="$temp_root/bindings.lua"
backup_looknfeel="$temp_root/looknfeel.lua"
backup_holiday_service="$temp_root/$HOLIDAY_UPDATE_UNIT.service"
backup_holiday_timer="$temp_root/$HOLIDAY_UPDATE_UNIT.timer"
transaction_open=1
had_plugin=0
had_shell=0
had_bindings=0
had_looknfeel=0
had_holiday_service=0
had_holiday_timer=0
if [[ -f "$UNIT_DIR/$HOLIDAY_UPDATE_UNIT.service" ]]; then
  install -m 644 "$UNIT_DIR/$HOLIDAY_UPDATE_UNIT.service" "$backup_holiday_service"
  had_holiday_service=1
fi
if [[ -f "$UNIT_DIR/$HOLIDAY_UPDATE_UNIT.timer" ]]; then
  install -m 644 "$UNIT_DIR/$HOLIDAY_UPDATE_UNIT.timer" "$backup_holiday_timer"
  had_holiday_timer=1
fi
previous_bar="omarchy.bar"
if [[ -f "$STATE_FILE" ]] &&
   jq -e --arg id "$PLUGIN_ID" '.schemaVersion == 1 and .pluginId == $id' "$STATE_FILE" >/dev/null 2>&1; then
  previous_bar="$(jq -r '.previousBarId // "omarchy.bar"' "$STATE_FILE")"
  saved_shell_backup="$(jq -r '.previousShellConfigBackup // empty' "$STATE_FILE")"
  if [[ -n "$saved_shell_backup" && -f "$saved_shell_backup" ]] &&
     jq -e '.version == 1' "$saved_shell_backup" >/dev/null 2>&1; then
    install -m 600 "$saved_shell_backup" "$temp_root/original-shell.before.json"
  fi
elif [[ -f "$LEGACY_STATE_FILE" ]] &&
     jq -e --arg id "$LEGACY_PLUGIN_ID" '.schemaVersion == 1 and .pluginId == $id' "$LEGACY_STATE_FILE" >/dev/null 2>&1; then
  previous_bar="$(jq -r '.previousBarId // "omarchy.bar"' "$LEGACY_STATE_FILE")"
  saved_shell_backup="$(jq -r '.previousShellConfigBackup // empty' "$LEGACY_STATE_FILE")"
  if [[ -n "$saved_shell_backup" && -f "$saved_shell_backup" ]] &&
     jq -e '.version == 1' "$saved_shell_backup" >/dev/null 2>&1; then
    install -m 600 "$saved_shell_backup" "$temp_root/original-shell.before.json"
  fi
fi

cleanup() { rm -rf -- "$temp_root"; }

rollback() {
  local status=$?
  (( transaction_open )) || return "$status"
  trap - ERR INT TERM EXIT
  warn "installation failed; restoring the previous Quattro state"
  if (( had_plugin )); then
    rm -rf -- "$TARGET"
    mv -- "$backup_plugin" "$TARGET"
  else
    rm -rf -- "$TARGET"
  fi
  if (( had_shell )); then
    install -m 600 "$backup_shell" "$SHELL_CONFIG"
  else
    rm -f -- "$SHELL_CONFIG"
  fi
  if (( had_bindings )); then
    install -m 644 "$backup_bindings" "$BINDINGS"
  else
    rm -f -- "$BINDINGS"
  fi
  if (( had_looknfeel )); then
    install -m 644 "$backup_looknfeel" "$LOOKNFEEL"
  else
    rm -f -- "$LOOKNFEEL"
  fi
  if [[ -f "$MPV_WRAPPER" ]] &&
     grep -Fq 'quickshell-astra-owned-mpv-screenrecord-action' "$MPV_WRAPPER"; then
    rm -f -- "$MPV_WRAPPER"
  fi
  systemctl --user disable --now "$HOLIDAY_UPDATE_UNIT.timer" >/dev/null 2>&1 || true
  if (( had_holiday_service )); then
    install -m 644 "$backup_holiday_service" "$UNIT_DIR/$HOLIDAY_UPDATE_UNIT.service"
  else
    rm -f -- "$UNIT_DIR/$HOLIDAY_UPDATE_UNIT.service"
  fi
  if (( had_holiday_timer )); then
    install -m 644 "$backup_holiday_timer" "$UNIT_DIR/$HOLIDAY_UPDATE_UNIT.timer"
    systemctl --user daemon-reload >/dev/null 2>&1 || true
    systemctl --user enable --now "$HOLIDAY_UPDATE_UNIT.timer" >/dev/null 2>&1 || true
  else
    rm -f -- "$UNIT_DIR/$HOLIDAY_UPDATE_UNIT.timer"
    systemctl --user daemon-reload >/dev/null 2>&1 || true
  fi
  omarchy-shell shell rescanPlugins >/dev/null 2>&1 || warn "plugin rescan failed during rollback"
  omarchy bar use "$previous_bar" >/dev/null 2>&1 || omarchy bar use omarchy.bar >/dev/null 2>&1 || true
  hyprctl reload >/dev/null 2>&1 || warn "Hyprland reload failed during rollback"
  cleanup
  exit "$status"
}
trap rollback ERR INT TERM EXIT

entry_point="$(jq -r '.entryPoints.bar // empty' "$repo_root/manifest.json" 2>/dev/null || true)"
[[ -f "$repo_root/manifest.json" && -n "$entry_point" && -f "$repo_root/$entry_point" ]] ||
  die "repository is incomplete: manifest.json or its Quattro bar entry point is missing"
jq -e --arg id "$PLUGIN_ID" '.schemaVersion == 1 and .id == $id and (.kinds | index("bar"))' \
  "$repo_root/manifest.json" >/dev/null || die "manifest.json does not describe the expected full-bar plugin"

info "Staging and validating the plugin"
git clone --quiet --no-hardlinks -- "$repo_root" "$stage"
# Overlay the local working tree so a checkout can install the code being
# validated without committing it first.
while IFS= read -r path; do
  if [[ -e "$repo_root/$path" ]]; then
    mkdir -p -- "$stage/$(dirname -- "$path")"
    install -m "$(stat -c '%a' "$repo_root/$path")" "$repo_root/$path" "$stage/$path"
  else
    rm -f -- "$stage/$path"
  fi
done < <(
  {
    git -C "$repo_root" ls-files --cached --others --exclude-standard
    git -C "$repo_root" diff --name-only HEAD
  } | sort -u
)
info "Installing pinned offline holiday data"
npm --prefix "$stage" ci --omit=dev --ignore-scripts --no-audit --no-fund
# npm creates command shims as symlinks, while Quattro plugins intentionally
# reject every symlink. date-holidays is consumed as a library, so no shim is
# needed at runtime.
rm -rf -- "$stage/node_modules/.bin"
[[ -x "$stage/scripts/holiday-helper.js" ]] ||
  die "repository is incomplete: scripts/holiday-helper.js is missing or not executable"
[[ -f "$stage/node_modules/date-holidays/LICENSE" ]] ||
  die "date-holidays runtime data or its license was not installed"
holiday_smoke="$(TZ=Asia/Kolkata XDG_CACHE_HOME="$temp_root/cache" \
  node "$stage/scripts/holiday-helper.js" get \
    --country auto --year 2026 --subdivision "" \
    --show-national true --show-regional true)"
jq -e '.ok == true and .country == "IN" and
  any(.holidays[]; .date == "2026-01-26" and .type == "public")' \
  <<<"$holiday_smoke" >/dev/null ||
  die "installed holiday helper failed its offline India smoke check"
regional_holiday_smoke="$(XDG_CACHE_HOME="$temp_root/cache" \
  node "$stage/scripts/holiday-helper.js" holidays IN 2026 TN \
    --show-national true --show-regional true)"
jq -e '.ok == true and .provider.id == "tn-government-2026" and
  any(.holidays[]; .date == "2026-01-15" and .name == "Pongal" and
    .scope == "regional" and .subdivisionCode == "TN")' \
  <<<"$regional_holiday_smoke" >/dev/null ||
  die "installed official Tamil Nadu holiday provider failed its offline smoke check"
recurring_holiday_smoke="$(XDG_CACHE_HOME="$temp_root/cache" \
  node "$stage/scripts/holiday-helper.js" holidays IN 2027 TN \
    --show-national true --show-regional true)"
jq -e '.ok == true and .provider.id == "tn-recurring-fixed" and
  any(.holidays[]; .date == "2027-01-01" and .name == "New Year'\''s Day" and
    .scope == "regional" and .subdivisionCode == "TN")' \
  <<<"$recurring_holiday_smoke" >/dev/null ||
  die "installed Tamil Nadu recurring fallback failed its offline smoke check"
omarchy plugin validate "$stage"
[[ -x "$stage/scripts/ai-usage-collector" ]] ||
  die "repository is incomplete: scripts/ai-usage-collector is missing or not executable"
[[ -x "$stage/scripts/astra-display-scale" ]] ||
  die "repository is incomplete: scripts/astra-display-scale is missing or not executable"
if [[ -e "$MPV_WRAPPER" ]] &&
   ! grep -Fq 'quickshell-astra-owned-mpv-screenrecord-action' "$MPV_WRAPPER"; then
  die "refusing to replace non-Astra MPV wrapper: $MPV_WRAPPER"
fi

mkdir -p -- "$PLUGINS_DIR" "$STATE_HOME" "$(dirname -- "$BINDINGS")"
for legacy_state_name in ai-usage.json holiday-settings.json holiday-annual-update.json; do
  if [[ ! -e "$STATE_HOME/$legacy_state_name" && -f "$LEGACY_STATE_HOME/$legacy_state_name" ]]; then
    install -m 600 "$LEGACY_STATE_HOME/$legacy_state_name" "$STATE_HOME/$legacy_state_name"
  fi
done
if [[ -e "$TARGET" ]]; then
  mv -- "$TARGET" "$backup_plugin"
  had_plugin=1
fi
if [[ -f "$SHELL_CONFIG" ]]; then
  install -m 600 "$SHELL_CONFIG" "$backup_shell"
  had_shell=1
  if [[ ! -f "$STATE_FILE" ]]; then
    previous_bar="$(jq -r '.bar.id // "omarchy.bar"' "$SHELL_CONFIG")"
  fi
fi
if [[ -f "$BINDINGS" ]]; then
  install -m 644 "$BINDINGS" "$backup_bindings"
  had_bindings=1
fi
if [[ -f "$LOOKNFEEL" ]]; then
  install -m 644 "$LOOKNFEEL" "$backup_looknfeel"
  had_looknfeel=1
fi

info "Installing the plugin atomically"
mv -- "$stage" "$TARGET"
# Deactivate the previous component before the registry clears the QML
# component cache. `rescanPlugins` is asynchronous.
omarchy bar use omarchy.bar >/dev/null
for _ in {1..40}; do
  if omarchy plugin list --json 2>/dev/null |
     jq -e --arg id "$PLUGIN_ID" 'any(.[]; .id == $id and (.active | not))' >/dev/null; then
    break
  fi
  sleep 0.05
done
omarchy-shell shell rescanPlugins >/dev/null
# The shell's rescan IPC starts an asynchronous unload -> clearComponentCache
# -> filesystem scan cycle. An already-known ID is not proof that this cycle
# has completed, so allow it to settle before selecting the bar again.
sleep 1
for _ in {1..40}; do
  if omarchy plugin list --json 2>/dev/null |
     jq -e --arg id "$PLUGIN_ID" 'any(.[]; .id == $id)' >/dev/null; then
    sleep 0.2
    break
  fi
  sleep 0.05
done
omarchy plugin enable "$PLUGIN_ID" >/dev/null
omarchy bar use "$PLUGIN_ID" >/dev/null

# Quattro owns AI usage scheduling inside the single shell process. Retire the
# classic per-provider systemd timers so only the normalized collector writes
# the new shared state.
for legacy_ai_unit in claude-usage codex-usage opencode-usage; do
  systemctl --user disable --now "$legacy_ai_unit.timer" >/dev/null 2>&1 || true
  rm -f -- "$HOME/.config/systemd/user/$legacy_ai_unit.service" \
    "$HOME/.config/systemd/user/$legacy_ai_unit.timer"
done
systemctl --user daemon-reload >/dev/null 2>&1 || true

info "Removing obsolete Astra idle overrides"
if [[ -f "$LEGACY_IDLE_WRAPPER" ]] &&
   grep -Fq 'quickshell-astra-owned-idle-toggle' "$LEGACY_IDLE_WRAPPER"; then
  rm -f -- "$LEGACY_IDLE_WRAPPER"
fi
rm -f -- "$HOME/.cache/quickshell/app-launcher/apps.json"
rmdir -- "$HOME/.cache/quickshell/app-launcher" 2>/dev/null || true
[[ -x "$TARGET/versions/default/modules/qs-gpu-probe.sh" ]] ||
  die "installed GPU probe is not executable"
cmp -s "$repo_root/versions/default/modules/qs-gpu-probe.sh" \
  "$TARGET/versions/default/modules/qs-gpu-probe.sh" ||
  die "installed GPU probe differs from staged source"
for network_file in \
  versions/default/services/NetworkSummaryService.qml \
  versions/default/services/NetworkModel.js \
  versions/default/modules/NetworkWidget.qml \
  versions/default/panels/NetworkPanel.qml; do
  cmp -s "$repo_root/$network_file" "$TARGET/$network_file" ||
    die "installed network runtime differs from staged source: $network_file"
done
for holiday_file in \
  runtime/Bar.qml \
  data/holidays/IN/TN/2026.json \
  data/holidays/IN/TN/recurring.json \
  scripts/holiday-helper.js \
  scripts/holiday-annual-update.js \
  scripts/import-regional-holidays.js \
  scripts/regional-holiday-provider.js \
  versions/default/services/HolidayCalendarModel.js \
  versions/default/services/HolidayService.qml \
  versions/default/services/HolidaySelection.js \
  versions/default/panels/CalendarPopup.qml \
  versions/default/modules/AtomicStateWriter.qml \
  versions/astra/Bar.qml; do
  cmp -s "$repo_root/$holiday_file" "$TARGET/$holiday_file" ||
    die "installed holiday runtime differs from staged source: $holiday_file"
done
for holiday_unit in \
  systemd/quickshell-astra-holiday-annual-update.service \
  systemd/quickshell-astra-holiday-annual-update.timer; do
  cmp -s "$repo_root/$holiday_unit" "$TARGET/$holiday_unit" ||
    die "installed holiday update unit differs from staged source: $holiday_unit"
done
cmp -s "$repo_root/versions/default/panels/HistoryPanel.qml" \
  "$TARGET/versions/default/panels/HistoryPanel.qml" ||
  die "installed Astra clipboard history panel differs from staged source"
for history_file in versions/default/panels/HistoryModel.js scripts/history-recording-preview.sh; do
  cmp -s "$repo_root/$history_file" "$TARGET/$history_file" ||
    die "installed Astra history runtime differs from staged source: $history_file"
done

info "Installing the Quattro Lua binding block"
bindings_temp="$temp_root/bindings.new"
if [[ -f "$BINDINGS" ]]; then
  awk -v begin="$BLOCK_BEGIN" -v end="$BLOCK_END" \
      -v legacy_begin="$LEGACY_BLOCK_BEGIN" -v legacy_end="$LEGACY_BLOCK_END" '
    $0 == begin || $0 == legacy_begin { managed=1; next }
    $0 == end || $0 == legacy_end { managed=0; next }
    !managed { print }
  ' "$BINDINGS" >"$bindings_temp"
fi
cat >>"$bindings_temp" <<LUA

-- BEGIN QUICKSHELL-ASTRA MANAGED BLOCK
hl.unbind("SUPER + CTRL + V")
o.bind("SUPER + CTRL + V", "Quickshell Astra clipboard history", "omarchy-shell quickshell-astra-clipboard toggle")
-- END QUICKSHELL-ASTRA MANAGED BLOCK
LUA
lua -e "assert(loadfile('$bindings_temp'))"
install -m 644 "$bindings_temp" "$BINDINGS"

info "Installing the history blur layer rule"
looknfeel_temp="$temp_root/looknfeel.new"
if [[ -f "$LOOKNFEEL" ]]; then
  awk -v begin="$BLUR_BLOCK_BEGIN" -v end="$BLUR_BLOCK_END" \
      -v legacy_begin="$LEGACY_BLUR_BLOCK_BEGIN" -v legacy_end="$LEGACY_BLUR_BLOCK_END" '
    $0 == begin || $0 == legacy_begin { managed=1; next }
    $0 == end || $0 == legacy_end { managed=0; next }
    !managed { print }
  ' "$LOOKNFEEL" >"$looknfeel_temp"
fi
cat >>"$looknfeel_temp" <<LUA

-- BEGIN QUICKSHELL-ASTRA HISTORY BLUR
hl.config({ decoration = { blur = { enabled = true } } })
hl.layer_rule({
  match = { namespace = "^quickshell-history$" },
  blur = true,
  ignore_alpha = 0
})
-- END QUICKSHELL-ASTRA HISTORY BLUR
LUA
lua -e "assert(loadfile('$looknfeel_temp'))"
install -m 644 "$looknfeel_temp" "$LOOKNFEEL"
hyprctl reload >/dev/null
[[ ! -e "$TARGET/versions/default/modules/IdleInhibitorWidget.qml" ]] ||
  die "obsolete private IdleInhibitorWidget was installed"
cmp -s "$repo_root/versions/default/modules/IdleWidget.qml" \
  "$TARGET/versions/default/modules/IdleWidget.qml" ||
  die "installed idle observer differs from repository source"
if hyprctl binds -j | jq -e '
  any(.[];
    (.description // "") == "Toggle idle inhibitor" or
    ((.key // "") == "I" and (.modmask // 0) == 68 and
     (.description // "") != "Toggle locking on idle"))' >/dev/null; then
  die "a Astra-owned or non-native SUPER+CTRL+I binding remains active"
fi
hyprctl binds -j | jq -e '
  any(.[]; (.key // "") == "I" and (.modmask // 0) == 68 and
           (.description // "") == "Toggle locking on idle")' >/dev/null ||
  die "Omarchy's native SUPER+CTRL+I binding is missing"
hyprctl binds -j | jq -e '
  any(.[];
    (.key // "") == "V" and (.modmask // 0) == 68 and
    (.description // "") == "Quickshell Astra clipboard history")' >/dev/null ||
  die "Quickshell Astra SUPER+CTRL+V clipboard binding is missing"

# Plugin replacement can leave the already-instantiated bar component in Qt's
# component cache. A supported shell restart is the cold-start contract and
# ensures health is read from the newly installed QML model.
info "Restarting omarchy-shell with the installed plugin"
"$OMARCHY_PATH/bin/omarchy-restart-shell"

info "Running Quattro health checks"
health_timeout="${QS_ASTRA_HEALTH_TIMEOUT:-15}"
health_deadline=$((SECONDS + health_timeout))
health_last_error="health checks have not started"
health_json=""
geometry_json=""
expected_windows="$(hyprctl monitors -j | jq 'length')"

while (( SECONDS < health_deadline )); do
  if ! omarchy-shell shell ping >/dev/null 2>&1; then
    health_last_error="omarchy-shell shell ping failed"
    sleep 0.25
    continue
  fi

  if ! plugins_json="$(omarchy-shell shell listPlugins 2>/dev/null)"; then
    health_last_error="shell listPlugins failed"
    sleep 0.25
    continue
  fi
  if ! jq -e --arg id "$PLUGIN_ID" \
      'any(.[]; .id == $id and .enabled and .active)' <<<"$plugins_json" >/dev/null; then
    health_last_error="plugin is not discovered, enabled, and active"
    sleep 0.25
    continue
  fi

  if ! config_json="$(omarchy-shell shell listShellConfig 2>/dev/null)" ||
     ! jq -e --arg id "$PLUGIN_ID" '.bar.id == $id' <<<"$config_json" >/dev/null; then
    health_last_error="effective shell config does not select $PLUGIN_ID"
    sleep 0.25
    continue
  fi

  if ! health_json="$(omarchy-shell quickshell-astra-health ping 2>/dev/null)"; then
    health_last_error="Astra health target is not registered yet"
    sleep 0.25
    continue
  fi
  if ! jq -e . <<<"$health_json" >/dev/null 2>&1; then
    health_last_error="Astra health returned malformed JSON: $health_json"
    sleep 0.25
    continue
  fi
  if jq -e '.fatalError != ""' <<<"$health_json" >/dev/null; then
    health_last_error="Astra reported a fatal initialization error: $(jq -r '.fatalError' <<<"$health_json")"
    break
  fi
  if ! jq -e --argjson expected "$expected_windows" \
      '.initialized == true and .ok == true and .windows > 0 and
       ($expected == 0 or .windows == $expected) and
       .gpu.displayModelReady == true and .gpu.parseStatus == "ok" and
       (.gpu.temperatureC | type == "number") and
       (.gpu.usagePercent | type == "number") and
       (.gpu.vramTotalMiB | type == "number") and
       .network.serviceInstances == 1 and
       (.network.connected | type == "boolean") and
       (.network.nearbyNetworkCount | type == "number")' <<<"$health_json" >/dev/null; then
    health_last_error="Astra is not initialized or window count does not match monitors: $health_json"
    sleep 0.25
    continue
  fi

  if ! geometry_json="$(omarchy-shell shell debugBarGeometry 2>/dev/null)" ||
     ! jq -e 'type == "array" and length > 0 and all(.[]; .visible == true and .width > 0 and .height > 0)' \
       <<<"$geometry_json" >/dev/null 2>&1; then
    health_last_error="debugBarGeometry is empty or invalid: ${geometry_json:-<no response>}"
    sleep 0.25
    continue
  fi

  shell_count="$(pgrep -af 'quickshell .*[/]omarchy/shell' | wc -l)"
  if [[ "$shell_count" -ne 1 ]]; then
    health_last_error="expected one omarchy-shell Quickshell process, found $shell_count"
    sleep 0.25
    continue
  fi
  legacy_rise_running=0
  while read -r candidate_pid; do
    candidate_args="$(tr '\0' ' ' <"/proc/$candidate_pid/cmdline" 2>/dev/null || true)"
    if [[ "$candidate_args" == *" -c bar"* ||
          "$candidate_args" == *" -p $HOME/.config/quickshell/bar"* ]]; then
      legacy_rise_running=1
      break
    fi
  done < <(pgrep -x quickshell || true)
  if (( legacy_rise_running )); then
    health_last_error="a legacy standalone Astra process is running"
    break
  fi

  health_last_error=""
  break
done

if [[ -n "$health_last_error" ]]; then
  warn "Astra health failed after ${health_timeout}s: $health_last_error"
  instance_id="$(quickshell list --all 2>/dev/null | awk '/^Instance / { gsub(/:$/, "", $2); print $2; exit }')"
  if [[ -n "$instance_id" ]]; then
    warn "Recent Astra QML diagnostics:"
    quickshell log -i "$instance_id" -t 1200 2>&1 |
      grep -Ei 'quickshell-astra|Bar\.qml|Loader|QQml|QML|module|singleton|required|undefined|null|TypeError|ReferenceError|failed to load|is not a type|is not installed|Cannot assign|Cannot read property' |
      tail -80 >&2
  fi
  die "$health_last_error"
fi
omarchy-shell quickshell-astra-clipboard ping >/dev/null ||
  die "Astra clipboard history IPC target is unavailable"
jq -e 'type == "array"' \
  "$HOME/.local/state/omarchy/clipboard-history.json" >/dev/null ||
  die "Omarchy clipboard history is unavailable or malformed"

info "Collecting normalized AI usage state"
if "$TARGET/scripts/ai-usage-collector"; then
  :
else
  collector_status=$?
  [[ "$collector_status" -eq 75 ]] ||
    warn "AI usage collector exited with status $collector_status"
fi
ai_diagnostic="$("$TARGET/scripts/ai-usage-collector" --diagnose 2>/dev/null || true)"
if ! jq -e '.initialized == true and (.providers | type == "object")' \
    <<<"$ai_diagnostic" >/dev/null 2>&1; then
  die "AI usage collector did not produce valid diagnostic state"
fi
for provider in codex claude opencode; do
  provider_status="$(jq -r --arg provider "$provider" '.providers[$provider].status // "never-collected"' <<<"$ai_diagnostic")"
  if [[ "$provider_status" != "ok" ]]; then
    warn "$provider AI usage: $provider_status"
  fi
done
cmp -s "$repo_root/scripts/ai-usage-collector" "$TARGET/scripts/ai-usage-collector" ||
  die "installed AI usage collector differs from repository source"
for display_file in \
  runtime/Bar.qml \
  versions/astra/Bar.qml \
  scripts/astra-display-scale \
  versions/default/services/DisplayModel.js \
  versions/default/services/DisplayService.qml \
  versions/default/modules/DisplayWidget.qml \
  versions/default/panels/DisplayPanel.qml; do
  cmp -s "$repo_root/$display_file" "$TARGET/$display_file" ||
    die "installed Display runtime differs from staged source: $display_file"
done

info "Installing the Omakut screen-recording notification action"
mkdir -p -- "$(dirname -- "$MPV_WRAPPER")"
install -m 755 "$TARGET/scripts/quickshell-astra-mpv" "$MPV_WRAPPER"
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

info "Installing the annual verified holiday update timer"
mkdir -p -- "$UNIT_DIR"
install -m 644 "$TARGET/systemd/$HOLIDAY_UPDATE_UNIT.service" \
  "$UNIT_DIR/$HOLIDAY_UPDATE_UNIT.service"
install -m 644 "$TARGET/systemd/$HOLIDAY_UPDATE_UNIT.timer" \
  "$UNIT_DIR/$HOLIDAY_UPDATE_UNIT.timer"
systemctl --user daemon-reload
systemctl --user enable --now "$HOLIDAY_UPDATE_UNIT.timer" >/dev/null
systemctl --user is-enabled "$HOLIDAY_UPDATE_UNIT.timer" >/dev/null ||
  die "annual holiday update timer was not enabled"

revision="$(git -C "$TARGET" rev-parse HEAD)"
timestamp="$(date --iso-8601=seconds)"
jq -n \
  --arg pluginId "$PLUGIN_ID" \
  --arg revision "$revision" \
  --arg previousBarId "$previous_bar" \
  --arg shellConfigBackup "$STATE_HOME/shell.before.json" \
  --arg pluginPath "$TARGET" \
  --arg bindingsPath "$BINDINGS" \
  --arg looknfeelPath "$LOOKNFEEL" \
  --arg blockBegin "$BLOCK_BEGIN" \
  --arg blockEnd "$BLOCK_END" \
  --arg timestamp "$timestamp" \
  --argjson schemaVersion "$SCHEMA_VERSION" \
  '{
    schemaVersion: $schemaVersion,
    pluginId: $pluginId,
    installedRevision: $revision,
    previousBarId: $previousBarId,
    previousShellConfigBackup: $shellConfigBackup,
    filesCreated: [$pluginPath],
    filesModified: [$bindingsPath, $looknfeelPath],
    managedLuaBlock: {begin: $blockBegin, end: $blockEnd},
    systemdUserUnits: ["quickshell-astra-holiday-annual-update.service",
      "quickshell-astra-holiday-annual-update.timer"],
    optionalBackends: {
      quattroClipboard: true,
      quattroNotifications: true,
      quattroOsd: true,
      tailscale: false,
      aiUsage: true
    },
    installedAt: $timestamp
  }' >"$temp_root/install-state.json"
if [[ -f "$temp_root/original-shell.before.json" ]]; then
  install -m 600 "$temp_root/original-shell.before.json" "$STATE_HOME/shell.before.json"
elif (( had_shell )); then
  install -m 600 "$backup_shell" "$STATE_HOME/shell.before.json"
fi
install -m 600 "$temp_root/install-state.json" "$STATE_FILE"

transaction_open=0
trap - ERR INT TERM EXIT

# Astra is now installed, selected, and healthy. Only now retire artifacts
# owned by the former Rise plugin; unrelated paths containing "rise" remain.
systemctl --user disable --now "$LEGACY_HOLIDAY_UPDATE_UNIT.timer" >/dev/null 2>&1 || true
rm -f -- "$UNIT_DIR/$LEGACY_HOLIDAY_UPDATE_UNIT.service" \
  "$UNIT_DIR/$LEGACY_HOLIDAY_UPDATE_UNIT.timer"
if [[ -d "$LEGACY_TARGET" && -f "$LEGACY_TARGET/manifest.json" ]] &&
   [[ "$(jq -r '.id // empty' "$LEGACY_TARGET/manifest.json" 2>/dev/null)" == "$LEGACY_PLUGIN_ID" ]]; then
  rm -rf -- "$LEGACY_TARGET"
fi
rm -rf -- "${XDG_CACHE_HOME:-$HOME/.cache}/quickshell-rise/holidays" \
  "${XDG_DATA_HOME:-$HOME/.local/share}/quickshell-rise/holidays"
rm -f -- "$LEGACY_STATE_HOME/install-state.json" \
  "$LEGACY_STATE_HOME/shell.before.json" \
  "$LEGACY_STATE_HOME/ai-usage.json" \
  "$LEGACY_STATE_HOME/holiday-settings.json" \
  "$LEGACY_STATE_HOME/holiday-annual-update.json"
rmdir -- "$LEGACY_STATE_HOME" 2>/dev/null || true
systemctl --user daemon-reload >/dev/null 2>&1 || true
omarchy-shell shell rescanPlugins >/dev/null 2>&1 || true
cleanup
info "Quickshell Astra is active inside omarchy-shell"
