# Runtime Ownership and Installation

## Authoritative and derived paths

| Purpose | Path | Ownership |
|---|---|---|
| Source configuration | `versions/default/` | Authoritative repository source |
| Source entry point | `versions/default/shell.qml` | Authoritative |
| Installed configuration | `~/.config/quickshell/bar/` | Project-owned copy when `.qsrise` exists |
| Live entry point | `~/.config/quickshell/bar/shell.qml` | Derived installed copy |
| Configuration name | `bar` | External compatibility contract |
| Ownership marker | `.qsrise` | Proves the installed tree is project-owned |
| Source marker | `.qsrise-source` | Records a local source checkout when available |
| User helpers | `~/.local/bin/` | Individually installed project entrypoints |
| Updater helpers | `~/.config/quickshell/bin/` | Project-owned updater/helper scripts |
| User units | `~/.config/systemd/user/` | Individually owned services/timers |
| Persistent updater checkout | `~/.local/share/quickshell-dots/` | Derived deployment source |
| History recording thumbnails | `~/.cache/quickshell-history-thumbs/` | Generated project cache removed on uninstall |

`install.sh` uses a local checkout when its directory contains `versions/`;
otherwise it shallow-clones the configured repository. It recursively copies
`versions/default` into a same-parent staging directory, writes ownership
metadata, preserves a customized installed `quotes.txt`, then atomically
renames the stage into place. A foreign pre-existing configuration is backed up.

Both remote self-update and local-source refresh run the same post-update
companion synchronization before relaunching the bar, so external helpers and
the copied QML tree cannot intentionally drift across update paths.

The live tree is not a symlink. Editing only the installed copy is unsupported.
After replacement, installation verifies complete source/installed file-path
parity and byte identity. Ownership metadata is installation-only, while the
required `quotes.txt` path is excluded from byte comparison because an existing
user-customized copy is intentionally preserved.

## Owned artifacts

`scripts/qs-owned-artifacts.tsv` is the machine-validated source/destination,
mode, and ownership-policy inventory. Installer and post-update consume its
rows through the path-confined `qs-artifact-manifest.sh` reader. Lifecycle
decisions remain explicit, while the manifest supplies source, destination and
mode for mandatory, foreign-guarded, autostart and optional-AI policies. A
complete temporary-home installer fixture covers repeat installation,
source/runtime parity, binding idempotency, foreign-wrapper refusal, autostart
transitions, command shims, and custom quote preservation. Every declared
destination retains standalone uninstall cleanup.

Current installed executable entrypoints include AI usage providers,
`qs-mode`, input/menu/theme/wallpaper/clipboard/emoji/capture/notification
helpers, and an owned `swayosd-client` compatibility wrapper. The updater owns
its check/apply/refresh scripts and binding helpers under the Quickshell bin
directory.

| Installed location | Current project-owned artifacts |
|---|---|
| `~/.local/bin/` | `claude-usage`, `codex-usage`, `opencode-usage`, provider module `qs_usage_cache.py`, `qs-mode`, `qs-managed-bindings`, `qs-rise-input`, `swayosd-client`, `qs-menu-action`, `qs-menu-data`, `qs-theme-switcher`, `qs-wallpaper-switcher`, `qs-clipboard`, `qs-emoji`, `qs-capture`, `qs-notification-silence`, `qs-state-write` |
| `~/.config/quickshell/bin/` | `qs-shell-check-update.sh`, `qs-shell-apply-update.sh`, `qs-shell-refresh-local.sh`, `ensure-hypr-launcher-binding.sh`, `ensure-hypr-switcher-blur-rules.sh` |
| `~/.local/lib/qs-rise/` | `qs-clipboard-filter.py`, private `elephant-bin/wl-paste` wrapper |
| `~/.config/systemd/user/elephant.service.d/` | `50-qs-rise-clipboard-privacy.conf` |
| `~/.config/omarchy/hooks/theme-set.d/` | `50-quickshell-bar.sh` |
| `~/.config/omarchy/hooks/post-boot.d/` | Optional `quickshell-rise` |

Project user units are:

- `claude-usage.service` and `claude-usage.timer`
- `codex-usage.service` and `codex-usage.timer`
- `opencode-usage.service` and `opencode-usage.timer`
- `qs-shell-update-check.service` and `qs-shell-update-check.timer`

The project also installs
`elephant.service.d/50-qs-rise-clipboard-privacy.conf`, an Omarchy theme hook,
and optionally the post-boot hook. Retired package-updater paths remain in
migration cleanup and are not current artifacts.

`qs-managed-bindings` is the authoritative current writer for launcher lines
and profile-managed binding blocks. `qs-mode`, installer/update compatibility
helpers, and current uninstall delegate to it; uninstall keeps an internal
fallback solely for installations that predate the helper.

Managed Hyprland ownership consists of three marker blocks in the selected
bindings file: `quickshell-rise managed menu bindings`, `managed media
bindings`, and `managed notification bindings`. The menu block has distinct
Quickshell and Omarchy command sets. A separate exact launcher/toggle helper
maintains `SUPER SPACE` launcher and `SUPER SHIFT SPACE` provider-toggle lines.
The look-and-feel file contains the `quickshell-rise managed switcher blur
rules` block for the native theme, wallpaper, and History window namespaces.
User lines outside these exact markers/lines are not owned.

## Update and uninstall

The self-updater maintains durable backups below
`${XDG_STATE_HOME:-~/.local/state}/qs-shell/backups`, stages a replacement bar,
and runs post-update integration refreshes. Post-update refreshes every
mandatory installed helper, updater unit, privacy wrapper/drop-in, and theme
hook. It refreshes optional autostart only when already installed and refuses
to overwrite a foreign `swayosd-client`. Binding refresh reapplies the recorded
Quickshell or Omarchy profile without starting either provider stack.

`uninstall.sh` refuses to remove a foreign bar directory without `.qsrise`. It
removes exact project-owned integrations and caches, keeps the editable local
AUR blacklist supplement, removes the owned bar, and restores the newest bar
backup if present. Generated History recording thumbnails are included in that
cache cleanup. It also changes live services and therefore must never be run
against a real home during normal validation. The isolated full-lifecycle
fixture executes it only with temporary roots and lifecycle command shims.

## Profile behavior

Mode is recorded in `${XDG_STATE_HOME:-$HOME/.local/state}/qs-rise/mode`.
`qs-mode quickshell` installs Quickshell menu/media/notification bindings,
reloads Hyprland, stops competing presentation services, starts
`qs -n -d -c bar`, and requires both instance discovery and `health ping`
before recording success. Failed startup falls back to the Omarchy service set.

`qs-mode omarchy` stops Quickshell, removes Quickshell media/notification
bindings, installs the Omarchy menu block, reloads Hyprland, and restores
Waybar, Walker, Mako, and SwayOSD. The optional boot hook reapplies the recorded
mode. Phase 0 tests record this contract but do not execute either transition.

`tests/qs-mode-isolated.test.sh` now executes both transitions against a fake
installed shell, temporary bindings/state, controlled health responses, and
lifecycle command shims. It protects binding idempotency and the current safety
contract that failed Quickshell health restores and records Omarchy.
