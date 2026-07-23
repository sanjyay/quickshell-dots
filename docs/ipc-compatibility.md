# IPC and Entrypoint Compatibility

The following 13 targets and 44 methods are the baseline external interface.
An absent tracked caller is not evidence that a method is removable.

| Target | Methods |
|---|---|
| `layout` | `lock`, `unlock` |
| `osd` | `show` |
| `notifications` | `dismiss`, `dismissAll`, `toggleDnd`, `invoke`, `restore` |
| `health` | `ping` |
| `menu` | `open`, `close`, `toggle`, `ping` |
| `emoji` | `open`, `close`, `toggle`, `ping` |
| `themeSwitcher` | `open`, `close`, `toggle`, `ping` |
| `wallpaperSwitcher` | `open`, `close`, `toggle`, `ping` |
| `clipboard` | `open`, `close`, `ping` |
| `capture` | `open`, `close`, `screenshot`, `recording`, `text`, `color`, `ping` |
| `theme` | `apply`, `applyLauncher`, `reload`, `setFont` |
| `picker` | `theme`, `wallpaper`, `screenshots`, `videos` |
| `launcher` | `open` |

`health ping` is part of profile startup validation. `picker wallpaper` is a
compatibility alias. `layout`, several `ping` methods, notification `restore`,
theme `apply`/`applyLauncher`, and picker `theme` have no tracked caller but may
be used externally and remain protected by the characterization test.

## Script entrypoints

The compatibility snapshot covers every tracked file directly below `scripts/`:

```text
claude-usage
codex-usage
ensure-hypr-launcher-binding.sh
ensure-hypr-switcher-blur-rules.sh
opencode-usage
qs-capture.sh
qs-clipboard-filter.py
qs-clipboard.sh
qs-elephant-wl-paste.sh
qs-emoji.sh
qs-managed-bindings.sh
qs-menu-action.sh
qs-menu-data.sh
qs-mode.sh
qs-notification-silence.sh
qs-state-write
qs-rise-input.sh
qs_usage_cache.py
qs-shell-apply-update.sh
qs-shell-check-update.sh
qs-shell-post-update.sh
qs-shell-refresh-local.sh
qs-theme-switcher
qs-verify-config-tree.sh
qs-wallpaper-switcher
swayosd-client
```

Installed command names may omit source suffixes. Changing source or installed
entrypoint names requires an explicit compatibility migration.

`qs_usage_cache.py` is an installed provider module rather than a user command;
it is included in the tracked script-file snapshot because Claude and OpenCode
import it from their installed directory.
