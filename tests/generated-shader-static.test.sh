#!/usr/bin/env bash
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source_file="$repo/versions/default/shaders/logo-tint.frag"
pack="$source_file.qsb"
expected_hash="273894db4725dc886ad3b62738838ba9e07633f92a04f52eef1baa2167ca8be2"

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
[[ -f "$source_file" && -f "$pack" ]] || fail "shader source or compiled pack missing"
[[ "$(sha256sum "$pack" | awk '{print $1}')" == "$expected_hash" ]] || fail "compiled shader changed without provenance update"

for consumer in modules/ClaudeWidget.qml modules/LauncherWidget.qml; do
  grep -Fq '../shaders/logo-tint.frag.qsb' "$repo/versions/default/$consumer" || fail "$consumer no longer references compiled shader"
done
grep -Fq 'layout(binding = 1) uniform sampler2D source;' "$source_file" || fail "source sampler contract changed"
grep -Fq 'vec4 tintColor;' "$source_file" || fail "source tint uniform missing"
grep -Fq 'src.a * ubuf.qt_Opacity' "$source_file" || fail "source alpha/opacity behavior changed"
grep -Fq "$expected_hash" "$repo/docs/generated-assets.md" || fail "documented checksum drifted"

printf 'ok (generated shader provenance contract)\n'
