# Providers and Polling

This inventory records current ownership; it is not a recommendation to merge
providers whose semantics differ.

| Source | Owners and cadence |
|---|---|
| PipeWire audio | Shared event-driven `AudioData`; `VolumePanel` additionally polls detailed sink/app/mic state every 2 seconds while visible |
| Network | `NetworkSummaryService` owns the bar summary, rate history, one-shot NetworkManager backend detection, and existing 2-second/60-second cadence; `NetworkPanel` separately probes detail, scans, rfkill, link speed, and connection actions |
| Bluetooth | `SystemStatusService` owns the existing 5-second global power/connected-count summary; the panel independently queries paired-device detail on open and after actions |
| CPU/GPU/RAM | `SystemMetricsService` owns one combined sample: 2 seconds for the enabled bar, 1.5 seconds while the system panel is open, and stopped when neither consumer needs it |
| AI quota | Three one-minute systemd timers are the sole scheduled writers; `AiUsageService` reads caches every 5/15 seconds and invokes providers only for an explicit panel-open refresh. `Theme` retains the public data/formatting API |
| Claude activity | `ClaudeWidget` checks active processes around every 5 seconds |
| Tailscale | `TailscaleService` owns startup/explicit reads and 10-second polling while enabled; `Theme` preserves aliases while the widget retains explicit up/down actions |
| Power profile | `SystemStatusService` owns the existing 5-second read cadence and mutations; Theme forwards the stable API and views retain UI behavior |
| Notification silence | `SystemStatusService` owns the existing 2-second helper poll and persisted-state mutation; per-monitor indicators only render and delegate clicks |
| Hypridle | `SystemStatusService` owns the existing 2-second process-presence poll and Omarchy toggle dispatch; per-monitor indicators only render and delegate clicks |
| Screen recording | `SystemStatusService` owns the adaptive 1/2-second process poll, elapsed state, and stop-in-flight coordination; per-monitor indicators retain presentation and input only |
| Voxtype | `SystemStatusService` owns the existing one-second optional-dependency/status probe; a missing binary still disables polling, while per-monitor widgets retain model/config actions |
| Privacy microphone | `SystemStatusService` owns the existing 2-second mute/activity read; per-monitor indicators and the volume panel consume it while retaining distinct mutation commands |
| Omarchy update | Long interval with shorter retry while update state is available |
| Shell update | Event-driven cache `FileView`; systemd timer checks every 6 hours |
| MPRIS | Native event-driven MPRIS state; panel has a 500 ms position timer |
| CAVA | Separate consumers in MPRIS panel and particle animation; merge only after live duplication proof |
| Camera | `helpers/camera-switch-monitor.py` owns the long-running input monitor; `CameraSwitchMonitor.qml` is the stable protocol adapter. Synthetic event tests cover press/release interpretation without opening real input devices |
| Theme/font | One-shot reads refreshed by the installed theme hook |
| Launcher applications | `helpers/app-launcher-scan.py` owns desktop-file discovery, filtering, icon resolution and atomic cache generation; `AppLauncherPanel.qml` owns cache consumption, UI filtering, selection and launch actions |

All `Process`, `Timer`, systemd timer, and long-running helper declarations are
considered provider ownership. Future provider consolidation must preserve
startup unavailable states, optional-dependency failures, visibility gating,
and explicit user refresh behavior.
