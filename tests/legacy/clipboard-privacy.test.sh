#!/usr/bin/env bash
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
filter="$repo/scripts/qs-clipboard-filter.py"

safe() { printf '%s' "$1" | "$filter" --check; }
sensitive() { ! printf '%s' "$1" | "$filter" --check; }

safe 'alex123'
safe 'Meeting moved to 10:30 tomorrow'
safe 'https://example.com/docs/getting-started'
sensitive 'person@example.com'
sensitive 'password: correct-horse-battery-staple'
sensitive 'username = alex123'
sensitive '123456'
sensitive 'ghp_abcdefghijklmnopqrstuvwxyz123456'
sensitive 'eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxMjM0NTY3ODkwIn0.signaturevalue'
sensitive $'-----BEGIN OPENSSH PRIVATE KEY-----\nsecret\n-----END OPENSSH PRIVATE KEY-----'
sensitive $'ABCD-EFGH-IJKL\nMNOP-QRST-UVWX\n'

rg -q 'elephant-bin' "$repo/systemd/elephant-clipboard-privacy.conf"
rg -q 'qs-clipboard-filter.py' "$repo/install.sh"
rg -q 'elephant-clipboard-privacy.conf' "$repo/install.sh"
rg -q '50-qs-rise-clipboard-privacy.conf' "$repo/uninstall.sh"
echo "ok (clipboard privacy filter)"
