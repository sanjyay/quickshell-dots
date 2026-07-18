#!/usr/bin/env bash
set -euo pipefail

case "${1:-query}" in
  query)
    # The async query emits one JSON response per history item. Bound the
    # collection window so the QML process can finish and parse the stream.
    set +e
    timeout 0.6 elephant query --async --json "clipboard;;${2:-120}"
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
  edit)
    [[ $# -eq 2 ]] || exit 2
    image_path=$2
    [[ $image_path = /* && -f $image_path && -r $image_path ]] || exit 3
    case "${image_path,,}" in
      *.png|*.jpg|*.jpeg|*.webp|*.bmp|*.gif) ;;
      *) exit 3 ;;
    esac
    screenshot_editor=${OMARCHY_SCREENSHOT_EDITOR:-satty}
    if [[ $screenshot_editor == satty ]]; then
      exec satty --filename "$image_path" \
        --output-filename "$image_path" \
        --actions-on-enter save-to-clipboard \
        --save-after-copy \
        --copy-command wl-copy
    fi
    exec "$screenshot_editor" "$image_path"
    ;;
  *) exit 2 ;;
esac
