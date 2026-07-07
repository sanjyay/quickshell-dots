# Changelog

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

