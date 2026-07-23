# State and Cache Formats

| Path | Format and ownership |
|---|---|
| `~/.cache/quickshell_widgets` | Legacy positional widget flags written atomically by `Theme.qml` |
| `~/.cache/quickshell_splits` | Control split, animation, and color selections, written atomically |
| `~/.cache/quickshell_barorder` | Widget group ordering with permutation validation, legacy migration, and atomic writes |
| `~/.cache/quickshell_barsplits` | Bar split positions, written atomically |
| `~/.cache/qs-rise-notifications.json` | Compact `{ "recent": [...] }` history; `NotificationManager` queues snapshots through `qs-state-write`, which validates JSON and atomically replaces the private file |
| `~/.cache/quickshell/app-launcher/apps.json` | Version-1 `{ generatedAt, apps }` JSON written atomically by `helpers/app-launcher-scan.py`; each app preserves name, exec, icon, desktop file, categories, keywords, and mtime |
| `~/.cache/quickshell-scan-*` | Generated theme, wallpaper, screenshot, and video scan data |
| `~/.cache/quickshell-*-thumbs` | Generated picker thumbnails |
| `~/.cache/quickshell-theme-switcher/` | Generated theme preview cache |
| `~/.cache/quickshell-wallpaper-switcher/` | Generated wallpaper preview cache |
| `~/.cache/claude-usage.json` | Atomically replaced Claude quota JSON, mode 0600 |
| `~/.cache/codex-usage.json` | Codex quota JSON, atomically replaced and mode 0600 |
| `~/.cache/opencode-usage.json` | Atomically replaced OpenCode quota JSON, mode 0600 |
| `~/.cache/qs-shell/update-available.json` | Atomic shell-update state contract |
| `${XDG_RUNTIME_DIR:-/tmp}/qs-rise-osd.json` | Ephemeral OSD bridge state |
| `${XDG_STATE_HOME:-~/.local/state}/qs-rise/mode` | Atomically replaced `quickshell` or `omarchy` profile |
| `${XDG_STATE_HOME:-~/.local/state}/qs-rise/notifications-silenced` | `qs-notification-silence`; one-line `0`/`1`, written by same-directory atomic rename with mode `0600` |
| `${XDG_STATE_HOME:-~/.local/state}/qs-shell/backups` | Durable updater rollback trees |
| `~/.config/quickshell/bar/.qsrise` | Installed ownership/config marker (`default`) |
| `~/.config/quickshell/bar/.qsrise-source` | Optional source checkout path |

Omarchy's current theme, `theme.name`, colors, and background symlink are
external authoritative state. Quickshell reads them or invokes Omarchy tools;
it does not own their formats.

The four bar setting files are intentionally retained during Phase 0. Their
positional formats and placeholder group IDs are compatibility constraints.
Future migration must parse old data, write atomically, tolerate malformed
files, and keep rollback possible.

## Legacy bar-setting schemas

`quickshell_widgets` is one space-delimited line with fields 0 through 35:

```text
memory legacyBrightness ai power bluetooth workspaceMode pickerStyle
legacyWeather clock12h network shadow radiusSmall heightMin workspaceStyle
barPosition border status quick cpu volume mpris aiTool frost logoMode
logoText logoIcon retired0 retired0 retiredFriday retired0 privacy battery
privacyMic privacyCamera clock reserved reservedLegacyPulse notifications
volumeManual aiUsageManual tailscale
```

Boolean values are encoded as `0`/`1`. Reserved and retired fields remain in
their positions. `quickshell_splits` is a space-delimited line containing
`splitArch splitMon splitMprisL splitNet barAnim barColor`; animation values 1–8
are migrated to current values 20–32 when read.

`quickshell_barorder` is `leftIds|centerIds|rightIds`, with comma-separated GIDs
inside each region. It is accepted only if it is a complete permutation of the
registry; a pre-Tailscale cache is migrated by appending G15. Each
`quickshell_barsplits` region is a string of `0`/`1` flags using the same
`left|right|boundary` separator structure.
