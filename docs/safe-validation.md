# Safe Validation Workflow

## Isolation rules

Characterization tests must create a temporary `HOME`, `XDG_CONFIG_HOME`,
`XDG_CACHE_HOME`, `XDG_STATE_HOME`, and `XDG_RUNTIME_DIR`. Desktop/service
commands must resolve to fail-fast shims. A test must abort if its temporary
home resolves to the invoking user's original home or if a target resolves
under the real Quickshell/Hyprland configuration.

Tests may inspect tracked source, run pure parsers, `bash -n`, and `qmllint`.
Lifecycle scripts may execute only with temporary HOME/XDG roots, explicit
real-home escape checks, and command shims for every reachable desktop or user
manager operation. They must never target the invoking user's live paths.

## Existing tests

Most tests are static source checks or use temporary directories and command
shims. Before Phase 0, 14 safe test entrypoints passed. The former failure in
`native-surfaces-static.test.sh` asserted the exact source literal
`titleWidth: 119`. Its intended contract is that the expanded MPRIS title area
is 119 pixels while compact mode is narrower. The replacement assertion checks
the current conditional structure and both values, avoiding the stale literal
shape while preserving the same geometry contract.

`bindings-install-uninstall.test.sh` now uses temporary HOME/XDG roots, rejects
paths resolving to the invoking user's real configuration, and prepends logging
shims for every lifecycle command reachable from uninstall. It asserts that
`systemctl` and Omarchy calls were intercepted. The test can therefore exercise
binding and blur-rule cleanup without reaching the real user manager or desktop.

`install-full-isolated.test.sh` exercises the complete local-source installer
and uninstaller lifecycle with those same safeguards. It covers repeat install,
full config parity, manifest artifacts and modes, foreign-wrapper refusal,
autostart transitions, binding idempotency, custom quotes, backup restoration,
owned-artifact cleanup, and preservation of unrelated user files. Git,
systemd, process control, Quickshell health, Hyprland and desktop services are
all shims; no live installation occurs.

Several other static tests assert exact source strings or pixel values. They
protect useful contracts but are brittle against equivalent refactors. Replace
them only alongside an isolated structural or behavioral test that proves the
same interaction, geometry, parser, or lifecycle behavior. Broad test rewriting
is intentionally deferred.

| Test/assertion group | Intended protection | Preferred replacement |
|---|---|---|
| `bar-insertion-reorder-static` function/source patterns | Reordering changes only after a valid insertion and cancels safely | Unit test the order model and invalid/valid drop transitions |
| `clock-widget-static` exact handlers, anchors, widths and margins | Full clock hit area, center-slot geometry and click/wheel behavior | QML geometry test plus synthesized pointer/wheel events |
| `gap-animations-static` exact mode/source patterns | Gap animation registry and split gating | Instantiate modes against a fake layout and assert activation/output bounds |
| `native-surfaces-static` panel strings, masks, keys, commands and pixel literals | Native panel availability, keyboard handling, dismissal, command routing and MPRIS geometry | Per-panel QML lifecycle/input tests and command-spy fixtures; the stale MPRIS title assertion is already structural |
| `network-panel-static` property and command literals | Available/saved network tabs and safe network actions | Provider-parser fixtures and panel model/action tests |
| `notification-osd-static` exact source and dimensions | Notification lifecycle, DND, OSD routing and bounded geometry | Fake notification server plus QML lifecycle/geometry tests |
| `tailscale-widget-static` property/command literals | Optional widget visibility, refresh and panel routing | Provider fixtures for missing, stopped, connected and error states |
| `wallpaper-switcher` source literals | Preview rollback, command validation and provider behavior | Existing temp-home command-spy test extended to session cancel/confirm |
| `install-source-resolution` literal installer fragments | Local-source selection, ownership metadata and installed verification | Extract a side-effect-free source-resolution function or run installer planning with all lifecycle commands shimmed |
| `codex-usage-static` QML/Python field names | Stable normalized quota fields | Keep Python unit fixtures; add a QML cache-consumer model test |
| `app-launcher-scan` fixtures | Desktop directory precedence, hidden-entry filtering, duplicate-name handling, icon lookup and atomic `apps.json` schema | Behavioral Python fixtures now protect the extracted helper; live launcher focus and launching still require Wayland validation |

Pure parser/filter tests (`clipboard-privacy`, `omarchy-menu-model`, emoji/menu
helper tests) already exercise behavior with fixtures or temporary homes and are
less dependent on QML source spelling.

## Safe command set

```bash
bash -n install.sh uninstall.sh scripts/*.sh hooks/50-quickshell-bar.sh \
  contrib/post-boot.d/quickshell-rise
bash tests/refactoring-baseline.test.sh
bash tests/bindings-install-uninstall.test.sh
bash tests/install-full-isolated.test.sh
bash tests/qs-mode-isolated.test.sh
bash tests/post-update-parity-isolated.test.sh
bash tests/config-tree-parity-isolated.test.sh
qmllint <relevant-qml-files>
git diff --check
```

Run other tests only after reading their command execution and confirming all
stateful dependencies are redirected or shimmed. Real installation, profile
changes, service operations, binding changes, and live Wayland interaction are
separate supervised validation activities.
