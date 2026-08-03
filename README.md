# Quickshell Astra for Omarchy Quattro

Quickshell Astra is a full-bar plugin for Omarchy Quattro. It runs inside the
single long-lived `omarchy-shell` process and adds Astra's bar, panels, widgets,
and helpers without starting a second Quickshell session.

This repository is for the Quattro plugin architecture only. It does not support
classic standalone `qs -c bar` usage.

## What it gives you

- A multi-monitor top or bottom bar with left, center, and right widget groups.
- Launcher, workspaces, clock, audio, MPRIS, battery, power profile, network,
  Bluetooth, microphone, weather, tray, system metrics, Tailscale, AI usage,
  idle, and update widgets.
- Astra control center and detail panels.
- Offline public-holiday markers and details in the calendar, with safe
  timezone-based country detection, an in-calendar searchable country/region
  selector, national/regional controls, an official bundled Tamil Nadu 2026
  calendar, and locally calculated Indian second/fourth-Saturday bank-closure
  markers. A persistent user timer checks each January 1 for the next verified
  annual Tamil Nadu file.
- Quattro-native notifications, clipboard history, OSD, lock/polkit, capture,
  theme, wallpaper, audio, Bluetooth, and network backends.
- A clipboard history panel on `SUPER+CTRL+V`.
- A read-only idle widget that observes Omarchy's native stay-awake state and
  only toggles when clicked.

## Install, update, uninstall

Install from a local checkout:

```bash
./install.sh
```

Update by pulling new commits and running the installer again:

```bash
git pull --ff-only
./install.sh
```

Remove Astra with:

```bash
./uninstall.sh
```

The installer stages the plugin atomically, installs the managed Hyprland
binding block, switches Omarchy to the Astra bar, and runs health checks. If a
step fails, the previous bar, shell config, and bindings are restored.

Installation state is recorded in:

```text
~/.local/state/quickshell-astra/install-state.json
```

## Where the code lives

```text
manifest.json                 Plugin manifest used by Omarchy Quattro
runtime/Bar.qml               Runtime adapter that waits for host injection
versions/astra/Bar.qml         Production bar composition
versions/default/modules/     Reusable widgets and shared controls
versions/default/panels/      Panels, popups, and pickers
versions/default/services/    Shared data services and collectors
scripts/                      Helper scripts and migration utilities
systemd/                      Optional user services and timers
hooks/                        Omarchy theme hook
contrib/post-boot.d/          Optional boot hook
tests/                        Static and fixture-based checks
docs/                         Architecture and migration notes
```

## How it is structured

- `runtime/Bar.qml` is the small host-facing entry point.
- `versions/astra/Bar.qml` builds the actual production bar once Omarchy's
  injected properties are ready.
- `versions/default/` contains the widgets, panels, and shared services.
- `Theme.qml` acts as the shared state and compatibility layer for the bar.
- `BarSlot.qml` places widgets on each monitor and keeps the layout consistent.

## Useful commands

```bash
omarchy-shell shell ping
omarchy-shell launcher open
omarchy-shell menu toggle
omarchy-shell quickshell-astra-clipboard toggle
omarchy plugin validate .
```

## Requirements

You need `git`, `jq`, `lua`, `hyprctl`, `node`, `npm`, and the Omarchy Quattro runtime.
Optional features such as Tailscale, power profiles, camera state, and the AI
provider CLIs only affect their own widgets.

The installer pins and installs the ISC/CC BY-SA 3.0 `date-holidays` package.
Calendar holiday lookups remain offline. The separately managed annual updater
uses HTTPS once each January 1 to retrieve a project-published, validated
official Tamil Nadu file; it never scrapes government pages or invents dates.
See
[docs/holidays.md](docs/holidays.md) for configuration, cache location,
troubleshooting, attribution, and limitations.

Legacy standalone pieces such as Elephant, Waybar, Mako, SwayOSD, Impala,
iwctl, classic hypridle hooks, and `qs-mode` are not part of the current bar.

## Further reading

- [docs/README.md](docs/README.md) for the documentation map.
- [docs/architecture.md](docs/architecture.md) for the active runtime layout.
- [docs/QUATTRO-MIGRATION.md](docs/QUATTRO-MIGRATION.md) for the feature and
  backend migration matrix.
- [SECURITY.md](SECURITY.md) for supported versions and private vulnerability
  reporting.

## License

MIT
