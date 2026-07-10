# Optional Snapper Access

The bar works without Snapper. `qs-package-update-state.sh` only runs
`snapper --csvout list` as the current user, with a six-second timeout and a
bounded output size. It never changes Snapper configuration, reads snapshot
contents, or treats a snapshot as proof that packages were updated.

If that command returns an access error, the bar reports `access-denied` as
optional evidence and continues using package-manager state.

## Administrator Opt-In

An administrator who wants a user to see snapshot metadata may configure the
specific Snapper config for that subvolume using Snapper's supported access
controls. The relevant settings in `/etc/snapper/configs/<config>` are:

```ini
ALLOW_USERS="alice"
# or, for a deliberately managed group:
ALLOW_GROUPS="snapper-readers"
SYNC_ACL="yes"
```

Replace `alice`, `snapper-readers`, and `<config>` with locally approved
values. Apply the change through the distribution's normal Snapper
administration procedure, review the resulting ACLs, and verify access as the
target user with `snapper --csvout list`.

This is optional. Do not make `/etc/snapper`, snapshot directories, or system
subvolumes globally readable or writable, and do not grant the bar write,
create, delete, rollback, or system-bus privileges.
