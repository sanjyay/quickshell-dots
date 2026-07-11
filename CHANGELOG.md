# Changelog

## 2026-07-12

### Widget Visibility

- Made the MPRIS now-playing pill visible only while a real player is playing, removing the idle music-note placeholder.
- Made the volume pill playback-aware so it appears only when the volume widget is enabled and media is currently playing.
- Added automatic AI usage visibility when Codex is active while keeping a manual control for users who want the pill pinned on.
- Added a separate notification bell toggle inside the status group so tray/status visibility and notification visibility can be managed independently.
- Persisted the new notification, volume, and AI visibility preferences in the widget cache.

## 2026-07-10

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
