# Omarchy Quattro Migration

Quickshell Rise is a full-bar plugin hosted by the single long-lived
`omarchy-shell` process. The installed Quattro implementation and its manifest
validator are authoritative; the plugin does not install or patch packaged
Omarchy files.

| Existing feature | Existing implementation | Quattro equivalent or API | Migration strategy | Final status | Validation performed |
| --- | --- | --- | --- | --- | --- |
| Multi-monitor Rise bar | Standalone `ShellRoot` and `PanelWindow` variants | Full-bar plugin hosted by `omarchy-shell` | Convert the root to the injected `Item` bar contract; retain per-output variants | Ported | Manifest validation, QML lint, live plugin health check |
| Left/center/right groups, ordering, splits, magnetic hover, unlock mode | `BarSlot.qml` and `Theme.qml` persisted state | Plugin-owned full-bar layout | Retain the mature Rise layout implementation inside the bar plugin | Ported | Existing layout tests plus QML lint |
| Workspaces, clock, calendar, tray, battery, power, weather, Tailscale, system metrics, media and AI usage | Rise widgets and panels | Quattro host plus Quickshell native services | Retain UI and non-singleton providers; optional command providers remain feature-scoped | Ported with optional-provider fallbacks | Existing static/provider tests |
| Theme colors | Direct parsing of classic `colors.toml` | `qs.Commons.Color` semantic roles | Map Rise paper, ink, accent and urgent roles to live Quattro colors | Ported | QML lint and live theme reload required |
| Notifications | Rise owned `NotificationServer` and toast stack | `omarchy.notifications` | Remove the second D-Bus owner and use the first-party notification service/UI | Adapted; Rise-specific toast styling is unavailable through the current public API | Source audit and single-owner runtime check required |
| Clipboard and history | Elephant query/activate plus Rise history panel | `omarchy.clipboard` and its JSON history | Remove Elephant runtime installation and summon the native history overlay | Adapted; native text/image restore, deletion and privacy behavior are used | First-party implementation audit; live clipboard test required |
| Hardware OSD | Rise overlay and SwayOSD bridge | `omarchy.osd` | Remove the duplicate overlay/bridge and retain the Quattro OSD | Adapted | Source audit; live media-key test required |
| Launcher and Super menu | Rise panels and standalone IPC handlers | `omarchy-shell` IPC and Quattro menu services | Keep Rise launcher in the bar plugin; bind through `omarchy-shell`; use Omarchy commands for system actions | Ported | Lua syntax and IPC ping |
| Theme and wallpaper pickers | Rise panels and classic theme hook | Quattro theme/wallpaper commands and live `Color` singleton | Keep presentation where non-conflicting; remove restart hook | Adapted | Static audit; live picker test required |
| Screenshot and recording | Rise capture panel and custom scripts | `omarchy capture` commands and first-party image picker | Delegate capture ownership to Quattro | Adapted | Command/API audit; live capture test required |
| Audio and microphone | PipeWire plus helper commands | Quattro audio commands and Quickshell PipeWire | Retain native PipeWire display; delegate global OSD and key actions | Adapted | QML lint; live audio test required |
| Idle / stay-awake | Rise-owned idle toggles and private inhibitor state | Omarchy native stay-awake service | Observe native state only; toggle only on explicit user click; never write back from state changes | Ported | Runtime state audit and one-way interaction test |
| Network | Mixed iwd/iwctl and NetworkManager fallback | Quattro NetworkManager APIs and commands | Quattro installation path treats NetworkManager as authoritative; iwd code is legacy-only pending panel extraction | Partial | Static audit; live network test required |
| Bluetooth | `bluetoothctl` UI | Quattro Bluetooth commands/service | Retain Rise display where compatible and use Quattro manager actions | Adapted | Static audit; live device test required |
| Vertical bar | Experimental geometry | Quattro supports left/right selection | Rise constrains supported placement to horizontal top/bottom until vertical geometry is ported | Explicitly unsupported | Configuration review |
| Installation and updates | Copied `~/.config/quickshell/bar`, classic hooks and standalone launch | `~/.config/omarchy/plugins`, `omarchy plugin`, `omarchy bar` | Transactional staged plugin replacement with state record and rollback | Ported | Isolated installer tests and live install required |
| Uninstall | Kill bar and restore classic provider stack | Switch bar, disable/rescan plugin, remove owned files | Restore recorded bar, strip only the marked Lua block, retain Quattro services | Ported | Static and repeated live uninstall required |

## Dependency Classification

| Classification | Dependencies |
| --- | --- |
| Quattro runtime invariant | Omarchy Quattro, `omarchy-shell`, Quickshell, Hyprland Lua configuration, NetworkManager, Quattro notification/clipboard/OSD services |
| Required project dependency | `git`, `jq`, `lua`, `hyprctl` |
| Optional feature dependency | Tailscale, power-profiles-daemon, Claude/Codex/OpenCode credentials or CLIs, Lenovo camera sysfs state |
| Obsolete dependency | Elephant, Waybar, Mako, SwayOSD, Impala, iwctl, classic hypridle hooks, `qs-mode` |

The obsolete names remain only where uninstall recognizes marker-owned artifacts
from older releases or where this document records the migration.

## Asynchronous Full-Bar Loader Contract

The installed Quattro host creates third-party bars with an asynchronous URL
`Loader` and assigns `omarchyPath`, `shell`, `manifest`, `barWidgetRegistry`,
`pluginRegistry`, and `barConfig` only from `Loader.onLoaded`. Consequently, a
third-party entry point cannot declare those properties `required` or construct
children that dereference them before injection.

Rise uses the same pattern for its idle observer. The widget reads Omarchy's
native stay-awake state, updates when the host changes it externally, and only
requests a backend toggle from an explicit click action.

Rise uses `runtime/Bar.qml` as a quiet adapter. Every injected property starts as an
empty string or `null`. `hostReady` becomes true only after the mandatory host
values arrive, and the idempotent `tryInitialize()` then activates the production
tree in `versions/rise/Bar.qml`. The production tree has its own guarded
`tryInitialize()` and reports a fatal shape error rather than starting with an
invalid `barConfig`.

The first captured production error was:

```text
versions/default/Bar.qml:20-22: Required property omarchyPath,
barWidgetRegistry, and barConfig was not initialized
```

It prevented object creation because host injection occurs after object creation.
During diagnosis, a smoke fixture also caught a missing `Quickshell.Io` import
(`IpcHandler is not a type`) and established that this Qt build retains failed
component URLs across plugin rescans. Cache-busted directories retaining the
conventional `Bar.qml` basename allowed testing without restarting or patching
the shell.

## Health Contract

`omarchy-shell quickshell-rise-health ping` returns JSON containing:

- plugin ID and generation;
- component-created and host-ready states;
- injected-property states;
- initialized state and fatal error;
- active screen and completed bar-window counts;
- optional degraded features.

The installer retries layered health checks for 15 seconds. It validates shell
ping, plugin discovery and active state, effective `bar.id`, health JSON,
initialization, monitor/window parity, non-empty `debugBarGeometry`, one shell
process, and absence of standalone Rise commands. On failure it prints the last
failed layer and filtered Quickshell diagnostics before transactional rollback.

The persistent smoke fixture is `tests/fixtures/smoke/Bar.qml`. It proves the host
contract with one small window per valid screen, structured health, and geometry;
it is never the production manifest entry point.
