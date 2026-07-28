# Quickshell Rise for Omarchy Quattro

Quickshell Rise is a custom full bar for the Omarchy Quattro shell. It runs as
the `io.github.sanjyay.quickshell-rise` plugin inside the one long-lived
`omarchy-shell` Quickshell process. It does not launch a second Quickshell
configuration or replace Quattro's notification, clipboard, OSD, lock, polkit,
capture, theme, wallpaper, audio, Bluetooth, or NetworkManager providers.

> This branch targets the Quattro alpha architecture introduced by Omarchy PR
> #6231. Classic Omarchy and standalone `qs -c bar` operation are unsupported.

## Install

From a local checkout:

```bash
./install.sh
```

Remote installation:

```bash
tmp="$(mktemp -d)"
git clone https://github.com/sanjyay/quickshell-dots.git "$tmp/quickshell-rise"
"$tmp/quickshell-rise/install.sh"
rm -rf "$tmp"
```

The installer validates Quattro, stages and validates the plugin, records the
current bar and shell configuration, installs the plugin atomically, selects it
with `omarchy bar use`, installs a marked Hyprland Lua binding block, and runs
health checks. A mandatory failure restores the previous plugin, bar,
`shell.json`, and bindings automatically.

Installation state is stored at:

```text
~/.local/state/quickshell-rise/install-state.json
```

## Update

Run the installer again from an updated checkout:

```bash
git pull --ff-only
./install.sh
```

For a plugin checkout installed through Omarchy's Git lifecycle:

```bash
omarchy plugin update io.github.sanjyay.quickshell-rise --yes
omarchy plugin rescan
omarchy bar use io.github.sanjyay.quickshell-rise
```

The project installer is preferred when migrations or binding changes are
included because it provides full transaction rollback.

## Rollback And Uninstall

An in-progress failed install rolls back automatically. To remove Rise:

```bash
./uninstall.sh
```

Uninstall switches away from Rise before deleting it, restores the recorded
previous bar when it remains valid (otherwise `omarchy.bar`), removes only the
marked Lua block and project-owned legacy artifacts, rescans plugins, reloads
Hyprland, and verifies shell IPC. Repeating uninstall is safe.

## Features

- Multi-monitor top or bottom full bar.
- Left, center, and right widget groups.
- Unlock mode, drag ordering, persisted group order, splitting, split gaps,
  magnetic hover, and configurable styling.
- Workspaces, clock/calendar, PipeWire audio, MPRIS, battery, power profiles,
  NetworkManager-facing network state, Bluetooth, microphone/privacy state,
  Lenovo camera switch state, weather, tray, system metrics, Tailscale, AI
  usage, native idle state, and shell-update state.
- Rise control center and non-singleton per-widget panels.
- Rise launcher, Super menu, theme/wallpaper presentation, media pickers, and
  configurable Tanzaku, Hearthstone, and Carousel picker styles where they do
  not compete with Quattro services.
- Quattro-owned notifications, clipboard/history, hardware OSD, capture,
  lock/polkit, theme, wallpaper, audio, Bluetooth, and network backends.
- The idle widget is a read-only observer of Omarchy’s native stay-awake
  state; it updates from external shortcut changes and only toggles when the
  user clicks it.

Vertical left/right placement is intentionally unsupported until Rise's custom
layout has correct vertical geometry. Use:

```bash
omarchy bar position top
# or
omarchy bar position bottom
```

## IPC

Use the canonical Quattro IPC:

```bash
omarchy-shell shell ping
omarchy-shell launcher open
omarchy-shell menu toggle
omarchy-shell shell toggle omarchy.clipboard
omarchy-shell shell toggle omarchy.emojis
```

Plugin and bar lifecycle:

```bash
omarchy plugin validate .
omarchy plugin rescan
omarchy plugin enable io.github.sanjyay.quickshell-rise
omarchy bar use io.github.sanjyay.quickshell-rise
```

## Dependencies

Required project tools are `git`, `jq`, `lua`, and `hyprctl`, in addition to the
Omarchy Quattro runtime. Tailscale, power profiles, Lenovo camera state, and AI
provider CLIs/credentials are optional and affect only their widgets.

Elephant, Waybar, Mako, SwayOSD, Impala, iwctl, classic hypridle hooks, and
`qs-mode` are obsolete and are never installed or started.

See [docs/QUATTRO-MIGRATION.md](docs/QUATTRO-MIGRATION.md) for the feature and
backend migration matrix, validation status, and exact technical limitations.

## Repository

```text
manifest.json                 Quattro plugin manifest
runtime/Bar.qml               Deferred full-bar plugin entry point
versions/rise/Bar.qml         Rise production bar composition
versions/default/modules/     Rise widgets and shared controls
versions/default/panels/      Rise non-singleton panels and pickers
versions/default/services/    Plugin-owned optional data adapters
scripts/                      Optional helpers and legacy migration sources
tests/                        Static and fixture validation
docs/                         Architecture and migration documentation
install.sh                    Transactional Quattro installer
uninstall.sh                  State-aware Quattro uninstaller
```

## License

MIT
