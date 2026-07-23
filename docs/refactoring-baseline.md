# Refactoring Baseline

Captured from tracked files at commit `5039a1c` on 2026-07-22. Counts are
physical lines. PNG and compiled shader binaries are excluded from textual
counts; documentation and datasets are not called code.

This table is the immutable pre-refactor baseline. Phase 1 subsequently removed
four confirmed-unreachable widget files, the now-unreachable Memory panel and
private popup state, and two definition-only Theme properties. The historical
largest-file table therefore intentionally still lists `MemoryPanel.qml`.
Documentation, tests, and later service extractions are not folded back into
the baseline.

## Counts

| Metric | Lines |
|---|---:|
| Naive `wc -l` over all tracked files | 41,461 |
| Tracked textual content | 27,095 |
| Maintainable runtime source | 25,815 |
| QML | 21,881 |
| Standalone JavaScript | 419 |
| Runtime shell | 2,616 |
| Runtime Python | 813 |
| systemd/runtime configuration | 86 |
| Tests | 766 |
| Documentation and legal text | 468 |
| Static dataset (`quotes.txt`) | 31 |
| Text assets (SVG) | 4 |
| Repository metadata | 11 |

The test-to-source line ratio is 2.97%, approximately one test line per 33.7
runtime-source lines. `assets/default.png` contributes 14,135 newline bytes to
the naive count but is a 4.2 MB binary image, not 14,135 lines of code. The
tracked `.qsb` shader is also binary and has no meaningful line count.

## Top-level textual lines

| Location | Lines |
|---|---:|
| `versions/` | 22,438 |
| `scripts/` | 2,573 |
| Repository root | 1,190 |
| `tests/` | 766 |
| `systemd/` | 86 |
| `hooks/` | 34 |
| `contrib/` | 8 |
| `assets/` | 0 |

## Largest runtime files

| Rank | File | Lines |
|---:|---|---:|
| 1 | `versions/default/modules/ParticleStream.qml` | 1,943 |
| 2 | `versions/default/Theme.qml` | 1,642 |
| 3 | `versions/default/BarSlot.qml` | 1,040 |
| 4 | `versions/default/panels/NetworkPanel.qml` | 843 |
| 5 | `versions/default/panels/ImageCarouselPanel.qml` | 650 |
| 6 | `versions/default/panels/ImageCarouselHearthstone.qml` | 649 |
| 7 | `versions/default/panels/ControlPanel.qml` | 644 |
| 8 | `versions/default/panels/OmarchyMenuPanel.qml` | 552 |
| 9 | `versions/default/panels/MediaBrowserHearthstone.qml` | 541 |
| 10 | `versions/default/panels/VolumePanel.qml` | 540 |
| 11 | `versions/default/panels/MediaBrowserPanel.qml` | 532 |
| 12 | `versions/default/panels/HistoryPanel.qml` | 548 |
| 13 | `versions/default/panels/CpuPanel.qml` | 514 |
| 14 | `versions/default/panels/ThemeSwitcherPanel.qml` | 503 |
| 15 | `versions/default/panels/MediaBrowserCarousel.qml` | 497 |
| 16 | `versions/default/panels/ImageCarouselCarousel.qml` | 472 |
| 17 | `versions/default/panels/AppLauncherPanel.qml` | 455 |
| 18 | `versions/default/panels/AiUsagePanel.qml` | 429 |
| 19 | `versions/default/panels/MprisPanel.qml` | 426 |
| 20 | `install.sh` | 416 |
| 21 | `versions/default/shell.qml` | 386 |
| 22 | `versions/default/panels/EmojiPickerPanel.qml` | 379 |
| 23 | `scripts/qs-mode.sh` | 361 |
| 24 | `versions/default/modules/ClaudeWidget.qml` | 359 |
| 25 | `versions/default/modules/CloudflareSpeedTest.qml` | 355 |
| 26 | `scripts/codex-usage` | 321 |
| 27 | `versions/default/HardwareOsdOverlay.qml` | 314 |
| 28 | `versions/default/panels/BluetoothPanel.qml` | 295 |
| 29 | `uninstall.sh` | 295 |
| 30 | `versions/default/modules/NetworkWidget.qml` | 291 |
| 31 | `versions/default/modules/CameraSwitchMonitor.qml` | 278 |
| 32 | `versions/default/modules/MprisWidget.qml` | 269 |
| 33 | `scripts/opencode-usage` | 268 |
| 34 | `scripts/qs-shell-apply-update.sh` | 258 |
| 35 | `scripts/qs-menu-action.sh` | 241 |
| 36 | `versions/default/modules/LauncherWidget.qml` | 239 |
| 37 | `versions/default/panels/WallpaperSwitcherPanel.qml` | 237 |
| 38 | `versions/default/panels/ShellUpdatePanel.qml` | 237 |
| 39 | `versions/default/panels/BatteryPanel.qml` | 222 |
| 40 | `versions/default/panels/MemoryPanel.qml` | 217 |

`Theme.qml`, `BarSlot.qml`, and `shell.qml` have the broadest responsibility.
Large picker files mix presentation with process/cache controllers. In contrast,
`ParticleStream.qml` is large but remains a cohesive hand-maintained animation
engine; its size alone is not evidence that it should be split.

## Reproduction

Use `git ls-files -z` as the input set. Classify by tracked path and extension,
exclude PNG and `.qsb` binaries from textual totals, and exclude tests,
documentation, datasets, assets, and repository metadata from maintainable
runtime source. Do not scan the installed `~/.config/quickshell/bar` copy.
