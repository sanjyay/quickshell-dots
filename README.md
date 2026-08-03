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

## Native Git plugin installation

In Omarchy/Shibumi, choose **Add plugin → From Git** and enter:

```text
https://github.com/sanjyay/quickshell-astra
```

Where the installed Omarchy version exposes the equivalent CLI, the relevant
commands are:

```bash
omarchy plugin add https://github.com/sanjyay/quickshell-astra
omarchy plugin enable io.github.sanjyay.quickshell-astra
omarchy bar use io.github.sanjyay.quickshell-astra
```

Inspect `omarchy plugin list --json` and the current bar first: the add flow may
already enable the plugin, and not every command is necessary on every Omarchy
release. This base path does not run `install.sh`, npm, edit Hyprland, or
install/enable a systemd timer. The bar and core features construct without
those extras; optional command-backed features degrade independently.

To opt into the pinned holiday runtime, Astra clipboard binding, and annual
holiday timer after native installation:

```bash
~/.config/omarchy/plugins/io.github.sanjyay.quickshell-astra/scripts/astra-setup-extras --all
```

Use `--dry-run`, `--holidays`, `--bindings`, or `--timer` for individual
parts. `scripts/astra-remove-extras` removes only these Astra-owned additions.

## Full local installation

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
binding and supporting pieces, performs Rise migration, switches Omarchy to the
Astra bar, and runs health checks. If a step fails, the previous bar, shell
config, and bindings are restored. This remains the complete transactional
installation path.

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

The native base needs Omarchy Quattro and its normal core desktop commands. The
full installer additionally requires `git`, `jq`, `lua`, `hyprctl`, `node`, and `npm`.
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

## Installation compatibility

| Feature | Native base | Native + extras | Full `./install.sh` |
| --- | --- | --- | --- |
| Astra bar, workspaces, launcher, clock, audio, core panels | Yes | Yes | Yes |
| Bundled Indian bank-closure calculation | Yes | Yes | Yes |
| `date-holidays` country/region dates | Degraded | Yes | Yes |
| Astra `SUPER+CTRL+V` managed Lua binding | No automatic edit | Optional | Yes |
| Annual verified holiday updater timer | No | Optional | Yes |
| Transactional activation, migration, and rollback | Native Omarchy lifecycle | Native lifecycle | Astra installer |

## Shibumi compatibility boundary

Astra is a standard external full-bar plugin. Shibumi plugins compatible with
the standard Omarchy bar contract may work through the external-bar adapter.
Advanced Shibumi-only layout editing requires the complete Shibumi host facade
and is outside this task. Installing Astra does not add an Astra card beside
V1, V2, and Omarchy Bar on Shibumi's Quick page; that behavior belongs to the
Shibumi-Shell repository. Astra does not vendor or imitate private Shibumi APIs.

## Further reading

- [docs/README.md](docs/README.md) for the documentation map.
- [docs/architecture.md](docs/architecture.md) for the active runtime layout.
- [docs/QUATTRO-MIGRATION.md](docs/QUATTRO-MIGRATION.md) for the feature and
  backend migration matrix.
- [SECURITY.md](SECURITY.md) for supported versions and private vulnerability
  reporting.

## License

MIT
