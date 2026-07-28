# Quickshell Rise and Omarchy Quattro

This document is a compact migration guide for people working on the repo.
It focuses on the pieces that matter when you are trying to understand why a
feature lives where it does.

## What Rise is

Quickshell Rise is a full-bar plugin hosted by the single long-lived
`omarchy-shell` process. It shares the Quattro runtime and should not create a
second Quickshell bar or replace Quattro-owned services.

## What is authoritative

The runtime contract is driven by the installed Quattro host. Rise must follow
that contract rather than guessing legacy paths or starting its own providers.
The current plugin entry points are:

- `manifest.json`
- `runtime/Bar.qml`
- `versions/rise/Bar.qml`

## What moved to Quattro

These areas are no longer owned by Rise as separate implementations:

- notifications
- clipboard capture and history storage
- hardware OSD
- lock and polkit handling
- theme and wallpaper switching
- audio and Bluetooth backends
- NetworkManager integration

Rise can still present some of those capabilities in its UI, but the underlying
service is Quattro-owned.

## What Rise still owns

Rise keeps its own UI composition, layout, panels, and plugin-local services for
things that are safe to present from the bar:

- bar layout and slot positioning
- panels and popups
- widget presentation and theming
- AI usage display
- system metrics presentation
- Tailscale presentation
- clipboard history panel
- launcher and menu surfaces where they do not conflict with Quattro services

## Read this when changing

- `README.md` for the user-facing overview.
- `docs/architecture.md` for the file and ownership map.
- `docs/runtime-ownership.md` for install and uninstall behavior.
- `docs/providers-and-polling.md` for how shared data is refreshed.
- `docs/ipc-compatibility.md` for public shell commands and IPC.

## Reminder

If a feature depends on Quattro state, do not add a second Rise-owned copy of
that state just to make the UI easier. Rise should observe the shared backend and
present it clearly.
