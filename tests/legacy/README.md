# Legacy Test Classification

These tests are preserved as migration evidence but are not part of the active
Quattro suite.

## Replaced By Quattro Contract Tests

- `bindings-install-uninstall.test.sh`
- `install-full-isolated.test.sh`
- `install-source-resolution.test.sh`
- `owned-artifacts-manifest.test.sh`
- `post-update-parity-isolated.test.sh`
- `qs-mode-isolated.test.sh`
- `quattro-plugin-static.test.sh`
- `refresh-local-isolated.test.sh`
- `artifact-manifest-library.test.sh`
- `config-tree-parity-isolated.test.sh`
- `managed-bindings-isolated.test.sh`

They assert the classic copied `~/.config/quickshell/bar` tree, `.conf`
bindings, standalone process switching, or old artifact manifest.

## Intentionally Removed Classic Behavior

- `clipboard-privacy.test.sh`
- `clock-widget-static.test.sh`
- `native-surfaces-static.test.sh`
- `notification-cache-static.test.sh`
- `notification-silence-provider-static.test.sh`
- `notification-silence-state-isolated.test.sh`
- `refactoring-baseline.test.sh`
- `notification-osd-static.test.sh`
- `qs-emoji.test.sh`
- `qs-menu-data.test.sh`
- `qs-menu-font-action.test.sh`

They assert Elephant or Astra-owned notification, clipboard, OSD, and standalone
IPC providers. Quattro owns those singleton services.

## Still-Valid Tests Requiring Service-Adapter Porting

- `ai-provider-static.test.sh`
- `bluetooth-provider-static.test.sh`
- `camera-monitor-static.test.sh`
- `idle-provider-static.test.sh`
- `legacy-state-writes-static.test.sh`
- `network-summary-provider-static.test.sh`
- `popup-lifecycle-static.test.sh`
- `power-profile-provider-static.test.sh`
- `privacy-mic-provider-static.test.sh`
- `system-metrics-provider-static.test.sh`
- `tailscale-widget-static.test.sh`
- `voxtype-provider-static.test.sh`
- `network-panel-static.test.sh`
- `wallpaper-switcher.test.sh`

Their feature behavior remains relevant, but their literal assertions target the
pre-migration `shell.qml` composition or an earlier `Theme.qml` service-alias
refactor. Runtime plugin loading and focused widget tests cover the currently
ported implementations until these tests are rewritten around injected Quattro
service adapters.
