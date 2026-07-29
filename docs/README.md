# Documentation Map

If you want the short version first, read the top-level `README.md`.
This folder holds the deeper notes that are useful when changing the bar,
installer, or migration behavior.

- `architecture.md`: which files create the live bar and which shared services own
  the current state.
- `runtime-ownership.md`: how installation, updates, rollback, and uninstall work.
- `ipc-compatibility.md`: the external commands and IPC endpoints the repo keeps.
- `providers-and-polling.md`: optional providers, refresh loops, and ownership.
- `state-and-cache.md`: what is stored on disk and how the caches are shaped.
- `holidays.md`: calendar holiday configuration, offline data, cache,
  troubleshooting, licensing, and limitations.
- `refactoring-baseline.md`: the tracked size and cleanup baseline.
- `safe-validation.md`: what can be tested safely without touching the live session.

The migration guide at `docs/QUATTRO-MIGRATION.md` is the best starting point if
you want to understand how Rise fits into Omarchy Quattro.
