# Security Policy

## Supported Versions

Quickshell Astra is developed as a rolling-release Omarchy Quattro plugin. Security
fixes are made on the current `main` branch; older commits and the retired
standalone `qs -c bar` architecture are not maintained.

| Version | Supported |
| --- | --- |
| Current `main` | Yes |
| Older commits and forks | No |
| Legacy standalone releases | No |

Before reporting a problem, reproduce it with the latest `main` branch when it
is safe to do so.

## Reporting a Vulnerability

Do not open a public issue, discussion, or pull request for a suspected
vulnerability.

Report it privately with
[GitHub Security Advisories](https://github.com/sanjyay/quickshell-astra/security/advisories/new).
If GitHub private reporting is unavailable, contact the repository owner
through their GitHub profile and ask for a private reporting channel. Do not
include sensitive details in that initial public contact.

Please include:

- The affected commit and Omarchy/Quattro version.
- A clear description of the impact and realistic attack scenario.
- Reproduction steps or a minimal proof of concept.
- The affected files, commands, IPC endpoints, or installed paths.
- Any suggested mitigation or fix.

Remove access tokens, API keys, cookies, clipboard contents, private prompts,
usernames, hostnames, IP addresses, and other personal data from logs and
screenshots. In particular, review output from provider CLIs, Quickshell logs,
Hyprland state, Tailscale, NetworkManager, and files under the user's cache,
config, data, and state directories before attaching it.

You should receive an acknowledgement within seven days. The maintainer will
then validate the report, assess its severity and scope, and coordinate a fix
and disclosure timeline. Reports that are not security vulnerabilities may be
redirected to the public issue tracker after sensitive details are removed.

Please allow a reasonable remediation period before public disclosure. Credit
will be given in the advisory or release notes if requested.

## Security Scope

The project installs QML, scripts, managed Hyprland bindings, and state in the
user session and runs inside the long-lived `omarchy-shell` process. Security
reports are especially useful for:

- Command or shell-argument injection.
- Unsafe handling of provider, network, clipboard, media, or notification data.
- Unauthorized file access, permission changes, or deletion.
- Installer, updater, rollback, or uninstaller ownership-boundary failures.
- IPC endpoints that expose sensitive data or privileged actions unexpectedly.
- Dependency or plugin-loading behavior that permits unintended code execution.

General bugs, visual defects, feature requests, and problems that require a
user to run arbitrary untrusted code with their own permissions should normally
be filed in the public issue tracker instead.
