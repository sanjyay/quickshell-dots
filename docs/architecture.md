# Current Architecture

## The short version

Rise runs as a full-bar plugin inside the single `omarchy-shell` process. The
repo's source of truth lives in `versions/default/`; the runtime entry points are
`manifest.json`, `runtime/Bar.qml`, and `versions/rise/Bar.qml`.

## Live entry points

- `runtime/Bar.qml` is the host-facing adapter. It waits for Omarchy to inject
  the plugin context before starting the real bar.
- `versions/rise/Bar.qml` is the production bar composition.
- `versions/default/shell.qml` is the wider legacy-style root used by the source
  tree, but the Quattro plugin path is what matters at runtime.
- `BarSlot.qml` creates per-monitor bar windows and places widgets into the
  left, center, and right groups.

## Who owns what

- `Theme.qml` provides the shared theme tokens, popup state, persisted widget
  settings, and IPC-facing compatibility layer.
- `SystemStatusService.qml` owns low-frequency global state such as power
  profile, notification silence, microphone privacy, recording, and Voxtype.
- `NetworkSummaryService.qml` and `SystemMetricsService.qml` own shared network
  rate and CPU/GPU/RAM sampling.
- `TailscaleService.qml` owns read-only daemon parsing plus explicit user
  connection actions.
- `AiUsageService.qml` owns Claude, Codex, and OpenCode collection, parsing,
  caching, and freshness tracking.
- `PopupSurface.qml` is the shared popup shell used by the pilot panels that have
  moved to the new shared popup contract.

## Reference map

```text
shell.qml
  -> Theme.qml -> services/SystemStatusService.qml
  -> BarSlot.qml -> modules/*Widget.qml -> shared modules/controls
  -> NotificationManager.qml -> NotificationToastOverlay.qml
  -> HardwareOsdOverlay.qml
  -> panels/*.qml
  -> LazyLoader -> image and media picker variants
```

`BarSlot.qml` is the authoritative place to check which widget component is used
for each group id. Panels may also be opened through IPC, so a widget is not the
only way a panel can become reachable.

## Scripts and helpers

- `install.sh` installs the bar tree, helper entry points, hooks, and systemd
  units.
- `scripts/qs-shell-post-update.sh` handles the self-update flow.
- `scripts/ensure-hypr-launcher-binding.sh` maintains the managed Hyprland block.
- `scripts/qs-shell-apply-update.sh` and `scripts/qs-shell-refresh-local.sh`
  support the update lifecycle.
- `hooks/50-quickshell-bar.sh` refreshes theme-related state after an Omarchy
  theme change.
- `contrib/post-boot.d/quickshell-rise` is the optional boot hook.

## Practical takeaway

If you are changing how something looks or reacts, start in `modules/` or
`panels/`. If you are changing how the data arrives, look in `services/` or the
helper scripts. If you are changing startup, installation, or cleanup, inspect
`install.sh`, `uninstall.sh`, and the managed binding helper together.
