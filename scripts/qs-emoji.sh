#!/usr/bin/env bash
set -euo pipefail

case "${1:-}" in
  query)
    query="${2:-}"
    limit="${3:-160}"
    [[ "$limit" =~ ^[0-9]+$ ]] && (( limit >= 1 && limit <= 300 )) || exit 64
    [[ "$query" != *$'\n'* && "$query" != *$'\r'* && "$query" != *$'\t'* ]] || exit 64
    timeout 0.8 elephant query --json "symbols;$query;$limit"
    ;;
  select)
    value="${2:-}"
    [[ -n "$value" && ${#value} -le 64 ]] || exit 64
    [[ "$value" != *$'\n'* && "$value" != *$'\r'* && "$value" != *$'\t'* ]] || exit 64
    printf '%s' "$value" | wl-copy
    hyprctl dispatch sendshortcut "SHIFT,Insert,activewindow" >/dev/null
    ;;
  *)
    printf 'usage: qs-emoji {query [text] [limit]|select value}\n' >&2
    exit 64
    ;;
esac
