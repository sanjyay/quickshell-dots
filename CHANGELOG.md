# Changelog

## Unreleased

### History Switcher

- Replaced the two-pane clipboard picker with a fullscreen blurred History
  switcher that presents clipboard text, images, and recent screen recordings
  in a curved card fan under `Super + Ctrl + V`.
- Kept Elephant restoration, deletion, stable entry IDs, and invisible
  type-ahead filtering while adding recording-file clipboard copy and a
  separate scissors action that opens the selected recording in Omakut.
- Prevented stationary-pointer hover feedback from changing the selected card,
  and batched initial clipboard and recording results to keep the fan stable as
  it opens.

### Bar Layout

- Compacted workspace buttons when more than four workspaces are visible so
  the workspace group does not crowd the centre and right-side bar groups.

### Installation And Cleanup

- Added the History window namespace to the managed Hyprland blur rules,
  verified the replacement panel during installation, and removed generated
  recording thumbnails during uninstallation.

- Updated the Codex usage parser and panel mapping so the bar follows the live account state instead of assuming a fixed 5h + weekly layout.

- Added a persistent, single-select Gap Anim section with thirteen themed gap effects, an efficient recommended combination, and a no-animation option.

- Changed edit-mode drag/drop from fixed-position swapping to insertion, so intervening widgets shift aside while the established left, centre, and right bar geometry remains stable.
- Replaced camera hardware OSD labels with a compact camera/camera-off icon state indicator.
- Made the installer create `bindings.conf` when needed and taught the uninstaller to remove the repo-managed Hyprland bindings and helper scripts again.

## 2026-07-17

### Tailscale Widget

- Added a default-off Tailscale status widget to the existing Widgets panel,
  persisted widget flags, and draggable bar-slot registry without introducing
  a separate configuration path. The full pill toggles the connection on
  left-click, right-click opens a native connection-information popup, and
  hover intentionally exposes no details.

## 2026-07-16

### Native Quickshell UI

- Added a native Omarchy wallpaper switcher with active-theme discovery,
  adaptive circular cover-flow navigation, debounced application and verified
  rollback, plus native menu, widget, IPC, and Hyprland shortcut routing.

- Added a native Omarchy theme switcher with user/stock theme discovery,
  asynchronous previews, animated cover-flow navigation, debounced instant
  application, rollback handling, and live palette refresh without Walker.
- Routed the installed theme binding, existing theme-picker IPC, and Super menu
  Style → Theme action to the same Quickshell theme-switcher panel.
- Added a reversible Quickshell/Omarchy profile switch for the native menu,
  clipboard picker, capture panel, power/session actions, and related
  Hyprland bindings.
- Refactored the custom Omarchy Super menu to use a structured internal
  Quickshell menu/action model, keeping normal nested navigation and empty
  submenu states out of Walker while preserving Omarchy backend commands for
  final actions.
- Removed the root Learn entry from the custom Super menu.
- Made long nested Super menu action lists grow to their content when screen
  space permits, tighten only those nested rows, and scroll only when the list
  cannot fit inside the monitor work area.
- Fixed no-result and back-navigation paths so the custom Super menu stays
  inside Quickshell instead of revealing the original Omarchy/Walker menu.
- Added native Quickshell screenshot and screen-recording choices while
  preserving Omarchy’s capture backends and restoring their original bindings
  in the Omarchy profile.
- Fixed keyboard navigation in the capture and screen-recording choice panels.
- Added a centered, keyboard-accessible Omarchy menu with nested navigation,
  invisible type-ahead selection, outside-click dismissal, and launcher-style
  focused-input handling.
- Restyled the custom app launcher to share the Super menu typography, row
  density, selection styling, opaque panel surface, and scrollbar language
  while preserving app discovery, filtering, launching, and keyboard behavior.
- Kept Now Playing visible for media paused through the bar widget, including
  returning to the earlier paused track after newer playback closes, while
  still filtering ordinary stale paused MPRIS entries.
- Added a two-pane clipboard history picker with compact scrolling results,
  full text previews, Elephant image previews, safe copy/delete actions, and
  responsive monitor-aware sizing.
- Added installer, uninstaller, runtime helper, and static validation coverage
  for the new native surfaces.

### Bar Alignment

- Reduced the clock-to-idle-indicator spacing and aligned the idle indicator
  with the clock while preserving the existing bar layout.

## 2026-07-12

### Widget Visibility

- Made the MPRIS now-playing pill visible only while a real player is playing, removing the idle music-note placeholder.
- Made the volume pill playback-aware so it appears only when the volume widget is enabled and media is currently playing.
- Added automatic AI usage visibility when Codex is active while keeping a manual control for users who want the pill pinned on.
- Added a separate notification bell toggle inside the status group so tray/status visibility and notification visibility can be managed independently.
- Persisted the new notification, volume, and AI visibility preferences in the widget cache.

## 2026-07-10

### Native Notifications And Hardware OSD

- Replaced Pulse with a native per-monitor notification stack and a dedicated non-interactive hardware OSD.
- Centralized D-Bus notification ownership, replacement IDs, timeouts, actions, DND, transient handling, and the 50-entry history cache.
- Added mode-aware SwayOSD compatibility routing and durable Mako/SwayOSD renderer exclusion while Quickshell mode is active.
- Expanded managed hardware and notification bindings while preserving Omarchy provider restoration.

### Pulse And Cleanup

- Renamed Dynamic Island to Pulse, enlarged it for better readability, and moved it into an independent top overlay so it remains visible when fullscreen hides the bar.
- Fixed GPU detection, temperature, utilization, and VRAM reporting with the shared GPU probe script.
- Fixed update-check flicker so update widgets stay hidden while checks run and only appear after updates are confirmed.
- Removed the accent glow experiment and restored static theme-based widget shadows.
- Removed window-aware focused-app accent coloring so the bar uses the selected theme color consistently.
- Cleaned up removed feature flags, controls, event readers, and dead styling code.

## 2026-07-09

### Privacy And Media Widgets

- Added Lenovo LOQ camera kill-switch monitoring through the Ideapad extra buttons input device.
- Updated camera and microphone privacy colors so inactive states use the bar color and active privacy-risk states use red.
- Removed the camera hover tooltip text while keeping the camera status indicator behavior.
- Made the volume widget interactive with mouse wheel adjustment and left-drag volume setting.

### App Launcher

- Added persistent application caching at `~/.cache/quickshell/app-launcher/apps.json`.
- Loaded cached applications immediately on startup and refreshed desktop entries silently in the background.
- Kept the existing no-cache scanning fallback for first run or missing cache.

## 2026-07-07

### System Info Widget

- Refined the system information section so CPU, GPU, and memory data are easier to read in the bar and panel.
- Updated the system info panel layout to reduce clutter while keeping the detailed stats available.
- Adjusted the clock/system-info integration in the bar so the compact bar state stays readable.
- Updated README documentation for the refined system information behavior.

### App Launcher

- Added a Quickshell app launcher panel.
- Centered the launcher on the display.
- Removed the launcher header section.
- Changed launcher results to text-only application names.
- Added a full-width rounded highlight behind the active launcher row.
- Made mouse hover, keyboard navigation, and search result selection use the same highlighted state.
- Filtered unwanted low-level entries such as Avahi, btop, and fcitx from launcher results.
- Improved launcher scrolling so all visible applications can be reached.

### Bar Layout And Widgets

- Fixed responsive bar hiding so AI usage and now playing can both stay visible when enabled.
- Restored the screen recording duration display.
- Reduced the now-playing title width so the bar remains less cluttered.
- Refined the narrow bar layout priority so lower-priority widgets hide before user-facing active widgets.
- Refined the launcher widget trigger behavior for the new app launcher panel.
- Added subtle magnetic hover animation for bar pills: hovered widgets scale slightly and nearby widgets pull inward without changing layout width.
- Added one-place tuning values for magnetic hover scale, neighbor pull, second-neighbor pull, and animation duration.

### Theme And Color Controls

- Simplified bar color choices to red, mauve, purple, and blue.
- Removed Catppuccin and Tokyo Night color scheme buttons from the bar color picker.
- Added migration handling for older cached theme/color option values.

### Installer And Update Flow

- Removed the install-time version prompt.
- Changed the default install target from `versions/V1` to `versions/default`.
- Removed visible `V1` references from the codebase.
- Enabled the AI usage backend by default instead of prompting for it.
- Kept `--no-ai-backend` available for users who want to skip AI usage backend setup.
- Updated shell update scripts to track and install the `default` config path.

### Repository And Documentation

- Renamed the packaged config from `versions/V1` to `versions/default`.
- Renamed `assets/V1.png` to `assets/default.png`.
- Updated README install commands to remove the version argument.
- Updated README project layout documentation for `versions/default`.
- Removed README stars, forks, and issues badge buttons.
- Removed README video embeds.
- Removed the checked-in screen recording video asset.
- Updated README and LICENSE attribution to `sanjyay`.

### Commits

- `17fde81` - `Refine system info widget`
- `0ca8913` - `docs: clean up README media and license`
- `4743fe5` - `feat: refine bar launcher and default config`
