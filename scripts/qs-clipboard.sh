#!/usr/bin/env bash
set -euo pipefail

case "${1:-query}" in
  query)
    elephant_socket="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/elephant/elephant.sock"
    if [[ ! -S $elephant_socket ]]; then
      systemctl --user start elephant.service >/dev/null 2>&1 || true
      for _ in {1..30}; do
        [[ -S $elephant_socket ]] && break
        sleep 0.1
      done
    fi
    # The async query emits one JSON response per history item. Bound the
    # collection window so the QML process can finish and parse the stream.
    set +e
    timeout 0.6 elephant query --async --json "clipboard;;${2:-120}" 2>/dev/null
    rc=$?
    set -e
    # Elephant 2.21 may exit 2 when timeout closes an otherwise successful
    # async stream after emitting the requested results.
    [[ $rc -eq 0 || $rc -eq 2 || $rc -eq 124 ]] || exit "$rc"
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
