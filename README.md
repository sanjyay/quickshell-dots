<h1 align="center"> Quickshell Rise </h1>

<h4 align="center"> My Quickshell bar for Omarchy — my new Rise journey into Quickshell starts here. Enjoy! </h4>

> This project is based on [HANCORE-linux/quickshell-dots](https://github.com/HANCORE-linux/quickshell-dots). Credit goes to HANCORE-linux for the original Quickshell Rise work; this repository is my maintained version with my own changes on top.

## Install / Remove

Install and start the bar for the current session:

```bash
curl -fsSL https://raw.githubusercontent.com/sanjyay/quickshell-dots/main/install.sh | bash
```

Install and keep the bar after reboot:

```bash
curl -fsSL https://raw.githubusercontent.com/sanjyay/quickshell-dots/main/install.sh | bash -s -- --autostart
```

Remove the bar and restore your previous config:

```bash
curl -fsSL https://raw.githubusercontent.com/sanjyay/quickshell-dots/main/uninstall.sh | bash
```

The installer backs up an existing config to `~/.config/quickshell/bar.bak.<timestamp>`.

## What You Get

| Area | Highlights |
|---|---|
| Bar layout | unlock mode, insert/reorder widget groups by drag/drop, persistent order, split groups, magnetic hover, top/bottom position |
| Control center | quick actions, widget toggles, notification visibility, workspace modes, bar style, and split controls |
| Pickers | theme, wallpaper, screenshot, and video pickers with Tanzaku, Hearthstone, and Carousel styles |
| Core widgets | workspaces, playback-aware volume, System info (CPU/GPU/RAM), battery, power profile, network, optional Tailscale status, Bluetooth, weather, MPRIS, tray, notifications |
| Privacy tools | microphone mute indicator/toggle and Lenovo LOQ camera kill-switch status |
| Updates | shell update badge, weekly scheduled package update badge, Arch/AUR counter, known-infected AUR safety check |
| AI usage | Claude, Codex, and OpenCode usage pill with provider switcher, detail panel, and automatic Codex activity visibility |
| Super menu | native Quickshell Omarchy menu with nested navigation, empty states, backend action dispatch, and no Walker submenu fallback |
| Native surfaces | top-right notification stack plus a compact upper-centred hardware OSD, both per monitor and visible in fullscreen |

<details>
<summary>Full feature list</summary>

| Module | Function |
|---|---|
| Unlock &amp; reorder | unlock the bar, drag widget-groups to swap positions, persistent |
| Image pickers | theme, wallpaper, screenshots, videos, 3 selectable styles, cached thumbnails |
| Self-update | in-bar badge only after a newer shell version is confirmed, one-click update and restart |
| Package updates | system + AUR counter shown after confirmed updates, scheduled weekday display, pre-install security check |
| AI usage | combined Claude, Codex, and OpenCode usage pill |
| Workspaces | switch, overview, 10 / 5 / active-only modes, dots / numbers / magic styles |
| Weather | current conditions, metric / imperial toggle |
| Clock | time, calendar, scroll 24h / 12h toggle, timezone picker |
| Tailscale | optional, reorderable status; left-click toggles `tailscale up` / `tailscale down`, right-click opens connection details, and hover stays silent |
| MPRIS | media controls |
| Notifications | native `org.freedesktop.Notifications` service, four-card top-right stack, actions, DND, history, unread count, and clear |
| System monitors | compact System info widget with CPU/GPU temperatures, CPU/GPU usage, VRAM, and RAM usage |
| Privacy tools | microphone mute state, active microphone clients, Lenovo LOQ camera hardware switch status |
| Speed test | manual Cloudflare speed test in the network panel |
| Control center | quick toggles, power, Bar Functions fly-out |
| Notification visibility | independent notification bell toggle inside the status group |
| Bar style | border, shadow, frost, pill radius, top/bottom position |
| Split groups | positional pill splits + Stream, Surge, Bolt, Bolt 2 gap animations |
| Magnetic hover | subtle pointer-only pill scale and neighbor pull animation without layout reflow |
| Hardware OSD | non-interactive upper-centred volume, brightness, media, lock, radio, profile, icon-only camera state, and display-state feedback |
| Keybind IPC | `qs -c bar ipc call themeSwitcher toggle` plus wallpaper/media picker IPC |
| Super menu | Quickshell-rendered Omarchy actions, nested sections, type-ahead, keyboard navigation, and no Walker submenu handoff |
| Per-widget panels | click widget to open its popup |

</details>

## Requirements

Built for **Omarchy / Hyprland**. In Quickshell mode it owns `org.freedesktop.Notifications` and hardware OSD presentation; `qs-mode omarchy` restores Mako, SwayOSD, Waybar, and upstream bindings. It also integrates with `omarchy-*` helpers, Omarchy theme files, Hyprland, MPRIS players, and Omarchy's hook system.

Required packages are checked by the installer:

Install `quickshell`, `git`, `jq`, `curl`, `ttf-jetbrains-mono-nerd`, and
`ttf-material-symbols-variable` through your distribution's normal administrator workflow.

<details>
<summary>Optional widget dependencies</summary>

Optional packages enable specific widgets:

Install `pamixer`, `power-profiles-daemon`, `bluez-utils`, `iwd`, `impala`,
`hypridle`, `gpu-screen-recorder`, and `psmisc` through your distribution's
normal administrator workflow.

Notes:

- `pamixer`, `pactl`, or `wpctl` support the audio and microphone controls. Most PipeWire setups already provide `wpctl`.
- `bluez-utils` provides `bluetoothctl`, which the Bluetooth widget currently uses.
- Lenovo LOQ camera switch monitoring reads the Ideapad extra buttons input device; if it cannot open the device, add your user to the input group or create a udev rule for that input device.
- `power-profiles-daemon` is needed for the power-profile widget.
- `iwd` and `impala` are used by the Wi-Fi panel on classic Omarchy setups. If NetworkManager is active, the panel opens `nmtui` instead.
- `gpu-screen-recorder` enables the screen-recording widget.
- `voxtype` is optional for the Voxtype widget.
- The install script checks required tools and warns about missing optional tools.
- AI usage backends are local-only. They write usage numbers to `~/.cache/*.json`, do not store API keys, and refresh on timers.

</details>

## Compatibility

This bar is built for classic Omarchy setups where Waybar is the stock bar. The installer stops Waybar so both bars do not overlap.

<details>
<summary>Omarchy 4 / omarchy-shell note</summary>

On **Omarchy 4.0 / omarchy-shell**, this setup is not tested yet. Omarchy 4 already ships its own Quickshell shell, so running both shells at the same time may create duplicate bars or conflicting keybinds. Use this on Omarchy 4 only if you know how to disable or separate the built-in shell.

</details>

## Usage

Most interactions follow one rule: click a widget to open its panel.

Common actions:

- Double-click an empty bar area to unlock drag/drop mode.
- Press `Esc` or click the dimmed backdrop to lock again.
- Open the launcher/control widget to change bar style, widgets, privacy module visibility, workspaces, logo, and splits.
- Use the widget controls to hide the notification bell independently from the status/tray group.
- Use `Control > Actions > Schedule Update` to choose the weekday for the package-update badge. Friday is the default.
- Use the self-update badge when it appears to update this shell from inside the bar.
- Use the System info widget for quick CPU/GPU temperatures; click it for CPU, GPU, VRAM, and RAM details. The GPU probe supports NVIDIA and DRM/sysfs GPU data for temperature, utilization, and VRAM where the driver exposes it.
- Use the network cluster for network, Bluetooth, microphone, and camera privacy controls.
- The Super menu is rendered and navigated by Quickshell. It keeps nested Omarchy action pages, empty submenu states, type-ahead, back navigation, and keyboard focus inside the custom themed menu while still running Omarchy's backend commands for final actions.
- The app launcher displays cached applications immediately from `~/.cache/quickshell/app-launcher/apps.json`, silently refreshes the cache in the background, and uses the same visual density and selection styling as the Super menu.
- Media and volume pills stay out of the bar until a real MPRIS player is playing. If you pause media by clicking the Now Playing widget, that player stays available in the bar and media panel until you resume it or the player disappears.
- The capture panel supports keyboard navigation, including the screen-recording audio choices, with `Up`, `Down`, `Enter`, and `Esc`.
- The AI pill shows remaining 5h Codex allowance in the bar when manually enabled or when Codex is active. Click it to open the usage panel, which shows the weekly Codex window and other AI providers.

<details>
<summary>Click bindings</summary>

| Widget | Left | Middle | Right | Scroll |
|---|---|---|---|---|
| Audio | mute toggle / drag to set volume | - | volume panel | volume |
| Clock | calendar | - | timezone picker | toggle 24h / 12h |
| System info | CPU/GPU/RAM panel | - | - | - |
| Power Profile | panel | - | cycle profile | - |
| Network | panel | - | open system manager | - |
| Bluetooth | panel with up to 3 paired devices | - | open Bluetooth manager | - |
| Microphone | mute toggle | - | - | - |
| Camera | - | - | - | - |
| AI usage | open quota panel | - | switch provider | - |
| Weather | panel | - | force refresh | - |
| Voxtype | cycle model | - | config | - |
| Workspace | switch workspace | - | overview | - |
| MPRIS | play / pause | - | toggle panel | - |
| Tray bar widget | toggle tray panel | - | - | - |
| Tray icon | activate | context menu | hide icon | - |

</details>

<details>
<summary>Theme / wallpaper keybinds</summary>

The installed Quickshell bindings provide native theme and wallpaper switchers:

| Action | Key | Omarchy default |
|---|---|---|
| Theme | `Super` + `Ctrl` + `Shift` + `Space` | Quickshell theme switcher |
| Wallpaper | `Super` + `Ctrl` + `Space` | Quickshell wallpaper picker |

To route those keys to this bar's pickers, add this to `~/.config/hypr/bindings.conf`:

```conf
unbind = SUPER CTRL SHIFT, SPACE
bind = SUPER CTRL SHIFT, SPACE, exec, qs -c bar ipc call themeSwitcher toggle
unbind = SUPER CTRL, SPACE
bindd = SUPER CTRL, SPACE, Quickshell wallpaper switcher, exec, qs -c bar ipc call -- wallpaperSwitcher toggle
```

`install.sh` creates `bindings.conf` if it does not already exist, and `uninstall.sh` removes the Quickshell-managed entries again.

Then run:

```bash
hyprctl reload
```

Other picker IPC commands:

```bash
qs -c bar ipc call picker screenshots
qs -c bar ipc call picker videos
```

`qs -c bar ipc call picker wallpaper` remains a compatibility alias for the native wallpaper switcher.

</details>

<details>
<summary>Manual autostart hook</summary>

If you did not install with `--autostart`, add the Omarchy post-boot hook manually:

```bash
mkdir -p ~/.config/omarchy/hooks/post-boot.d
curl -fsSL -o ~/.config/omarchy/hooks/post-boot.d/quickshell-rise \
  https://raw.githubusercontent.com/sanjyay/quickshell-dots/main/contrib/post-boot.d/quickshell-rise
chmod +x ~/.config/omarchy/hooks/post-boot.d/quickshell-rise
```

Remove only the hook:

```bash
rm -f ~/.config/omarchy/hooks/post-boot.d/quickshell-rise
```

</details>

## Updates

The bar checks for shell updates and shows an update badge only after this repo is confirmed to have a newer version. Refreshes clear stale update state first, so the badge stays hidden while checks are running and when no update is available.

<details>
<summary>Shell updates and Arch/AUR safety checks</summary>

Click the shell update badge to review changes and apply the update.

Package updates run through the ArchUpdater panel. It checks packages against the known-infected AUR list and blocks known-bad packages from the update command.

</details>

## Repo Structure

<details>
<summary>Project layout</summary>

The `versions/default/` folder is the complete, self-contained bar config.

```text
versions/default/
├── shell.qml        # entry point
├── BarSlot.qml      # slot-based bar
├── Theme.qml        # colors, state, flags
├── Palette.js       # reads Omarchy colors.toml
├── IconMap.js       # icon name to codepoint
├── assets/          # bundled logo assets
├── modules/         # bar widgets
└── panels/          # popups and overlays
```

</details>

## Credits

This repository is based on [HANCORE-linux/quickshell-dots](https://github.com/HANCORE-linux/quickshell-dots). Thanks to HANCORE-linux for the original Quickshell Rise project and design foundation.

Parts of the original project are adapted from [Omarchy Shell](https://github.com/basecamp/omarchy/tree/omarchy-shell) and modified to integrate with Quickshell Rise. This includes the Carousel picker and selected widget functionality.

The Tanzaku and Hearthstone pickers are original implementations created for this project.

## License

[MIT](LICENSE) © 2026 sanjyay
