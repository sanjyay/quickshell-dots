#!/usr/bin/env bash
set -euo pipefail
case "${1:-menu}" in
  menu) exec qs -c bar ipc call -- capture open ;;
  screenshot) omarchy-capture-screenshot ;;
  recording) omarchy-capture-screenrecording ;;
  recording-no-audio) omarchy-capture-screenrecording ;;
  recording-desktop) omarchy-capture-screenrecording --with-desktop-audio ;;
  recording-mic) omarchy-capture-screenrecording --with-desktop-audio --with-microphone-audio ;;
  recording-webcam) omarchy-capture-screenrecording --with-desktop-audio --with-microphone-audio --with-webcam ;;
  text) omarchy-capture-text-extraction ;;
  color) pkill hyprpicker 2>/dev/null || hyprpicker -a ;;
  stop) omarchy-capture-screenrecording --stop-recording ;;
  *) exit 2 ;;
esac
