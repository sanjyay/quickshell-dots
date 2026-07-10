#!/usr/bin/env bash
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
require() {
  local needle="$1" file="$2"
  grep -Fq -- "$needle" "$file" || fail "missing '$needle' in $file"
}

require 'source_ref="$src_repo"' "$repo/install.sh"
require 'printf '\''%s\n'\'' "$source_ref" > "$stage/.qsrise-source"' "$repo/install.sh"
require 'verify_installed_copy()' "$repo/install.sh"
require 'Installed $rel does not match' "$repo/install.sh"
require 'shell.qml' "$repo/install.sh"

require 'DEST/.qsrise-source' "$repo/scripts/qs-shell-check-update.sh"
require 'DEST/.qsrise-source' "$repo/scripts/qs-shell-apply-update.sh"
require 'DEST/.qsrise-source' "$repo/scripts/qs-shell-refresh-local.sh"
require 'QS_SHELL_SOURCE' "$repo/scripts/qs-shell-check-update.sh"
require 'QS_SHELL_SOURCE' "$repo/scripts/qs-shell-apply-update.sh"

printf 'ok (install source resolution)\n'
