#!/usr/bin/env bash
set -euo pipefail

case "${1:-query}" in
  query)
    # The async query emits one JSON response per history item. Bound the
    # collection window so the QML process can finish and parse the stream.
    set +e
    timeout 0.35 elephant query --async --json "clipboard;;${2:-40}"
    rc=$?
    set -e
    [[ $rc -eq 0 || $rc -eq 124 ]] || exit "$rc"
    ;;
  copy)
    [[ $# -ge 2 ]] || exit 2
    elephant activate "clipboard;$2;copy;;" >/dev/null
    ;;
  delete)
    [[ $# -ge 2 ]] || exit 2
    elephant activate "clipboard;$2;remove;;" >/dev/null
    ;;
  *) exit 2 ;;
esac
