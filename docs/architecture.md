# Current Architecture

## Active roots

`versions/default/shell.qml` is the Quickshell composition root. It creates one
`Theme`, notification and camera managers, IPC handlers, and per-screen
`BarSlot`, popup-dismiss, notification-toast, and OSD surfaces. Normal panels
are instantiated from this root. Image and media picker variants use
`LazyLoader` so only the selected visual implementation is loaded.

`Theme.qml` remains the compatibility facade for visual tokens, popup flags,
placement, persisted widget settings, AI state, Tailscale, OSD routing, and
theme IPC. `services/SystemStatusService.qml` now owns the low-frequency global
power-profile, notification-silence, Hypridle, microphone-privacy,
screen-recording, and Voxtype processes. Theme aliases and forwarding methods
preserve the established API for panels, widgets, IPC, and particle effects.
`services/NetworkSummaryService.qml` and `services/SystemMetricsService.qml`
similarly own global network-rate and CPU/GPU/RAM sampling while detailed panel
actions remain panel-specific.
`services/TailscaleService.qml` owns read-only daemon status and parsing while
the widget retains explicit user-requested connection actions.
`services/AiUsageService.qml` owns Claude, Codex, and OpenCode cache parsing,
freshness, explicit refreshes, and reset formatting. `Theme` retains aliases
and forwarding functions consumed by the bar, panel, and particle warnings.
`helpers/camera-switch-monitor.py` owns the long-running camera-switch input
reader. `modules/CameraSwitchMonitor.qml` retains the existing QML state and
line-protocol adapter, so hardware parsing no longer lives inside a visual
component.
`BarSlot.qml` owns per-monitor layer windows, widget registration, ordering,
splits, dynamic visibility, drag/drop and the pointer containment mask.

Phase 2 introduces `modules/PopupSurface.qml` as a narrow pilot abstraction.
It owns the common popup screen, fullscreen anchors, overlay layer, reveal
animation, visibility threshold, namespace, and exclusive-focus transition.
`WorkspacePanel.qml` is the sole pilot consumer. Outside-click consumption,
Escape, card geometry, workspace data, and actions remain panel-owned until live
Wayland validation proves the shared boundary.

## QML reference map

The reference graph is rooted at `shell.qml` and follows QML type names,
`Loader`/`LazyLoader` sources, and component declarations. Important paths are:

```text
shell.qml
  -> Theme.qml -> services/SystemStatusService.qml
  -> BarSlot.qml -> modules/*Widget.qml -> shared modules/controls
  -> NotificationManager.qml -> NotificationToastOverlay.qml
  -> HardwareOsdOverlay.qml
  -> panels/*.qml
  -> LazyLoader -> image and media picker variants
```

`BarSlot.qml` maps group IDs to concrete widget components and is therefore an
authoritative reference even when a type name does not appear in `shell.qml`.
Panel visibility is generally routed through `Theme` properties and methods.
IPC-triggered panels must be considered reachable even without a widget caller.

The baseline reference scan found no tracked type/path reference for
`IdleInhibitorWidget.qml`, `MediaBrowserWidget.qml`, `ThemeDisplayWidget.qml`,
or `MemoryWidget.qml`. Phase 1 removed these four unreachable implementations
and added a regression guard. The later reference audit confirmed that
`MemoryPanel.qml` was reachable only from the already-removed `MemoryWidget`
and had no IPC entrypoint, so its eager shell instance and private visibility
state were removed as well. G4, G10, and G13 placeholders, `modMemory`, and
legacy positional fields remain to preserve layout/cache compatibility.

## Script/helper reference map

- `install.sh` installs the bar tree, helper entrypoints, hooks, systemd units,
  privacy drop-in, updater, and profile switcher.
- `qs-mode.sh` is invoked by the launcher toggle binding and post-boot hook.
- `qs-rise-input.sh`, `qs-capture.sh`, and IPC calls are invoked by managed
  Hyprland bindings.
- `qs-menu-action.sh`, `qs-menu-data.sh`, `qs-theme-switcher`,
  `qs-wallpaper-switcher`, `qs-clipboard.sh`, and `qs-emoji.sh` are invoked by
  QML panels or the native-menu model.
- `claude-usage`, `codex-usage`, `opencode-usage`, and
  `qs-shell-check-update.sh` are run by user systemd units/timers.
- `qs-shell-apply-update.sh`, `qs-shell-refresh-local.sh`, and
  `qs-shell-post-update.sh` form the self-update path.
- `qs-artifact-manifest.sh` is an internal sourced library that validates and
  resolves owned-artifact destinations; it is not an installed entrypoint.
- `ensure-hypr-launcher-binding.sh` and
  `ensure-hypr-switcher-blur-rules.sh` are used by installation and update
  flows.
- `50-quickshell-bar.sh` is the installed Omarchy theme hook;
  `contrib/post-boot.d/quickshell-rise` is the optional boot hook.
- `swayosd-client` and `qs-elephant-wl-paste.sh` have path-based compatibility
  use and must not be classified as unused from textual references alone.

## Layer assessment

UI surfaces, reusable controls, models, scripts, systemd units, and installation
are visibly separated by directory. Provider/state ownership, popup lifecycle,
process execution, persistence, and managed bindings remain the principal
refactoring seams. The system-status service and atomic writer are narrow
runtime layers introduced behind existing compatibility APIs.

The launcher application scanner lives in `helpers/app-launcher-scan.py`.
`AppLauncherPanel.qml` is the cache consumer and retains UI filtering,
selection, focus and launch behavior. Temporary desktop/icon fixtures protect
directory precedence, duplicate names, hidden or malformed entries, icon
resolution, atomic replacement and the version-1 cache schema.
