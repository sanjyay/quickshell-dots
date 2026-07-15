#!/usr/bin/env bash
set -euo pipefail

action="${1:-}"
case "$action" in
  apps) exec qs -c bar ipc call -- launcher open ;;
  about) exec omarchy-launch-about ;;
  learn.keybindings) exec omarchy-menu-keybindings ;;
  learn.omarchy) exec omarchy-launch-webapp 'https://learn.omacom.io/2/the-omarchy-manual' ;;
  learn.hyprland) exec omarchy-launch-webapp 'https://wiki.hypr.land/' ;;
  learn.arch) exec omarchy-launch-webapp 'https://wiki.archlinux.org/title/Main_page' ;;
  learn.neovim) exec omarchy-launch-webapp 'https://www.lazyvim.org/keymaps' ;;
  learn.bash) exec omarchy-launch-webapp 'https://devhints.io/bash' ;;
  trigger.transcode) exec omarchy-transcode ;;
  capture.screenshot) exec omarchy-capture-screenshot ;;
  capture.screenrecord) exec omarchy-capture-screenrecording ;;
  capture.text) exec omarchy-capture-text-extraction ;;
  capture.color) exec bash -lc 'pkill hyprpicker 2>/dev/null || hyprpicker -a' ;;
  reminder.show) exec omarchy-reminder show ;;
  reminder.set) exec omarchy-menu trigger ;;
  reminder.clear) exec omarchy-reminder clear ;;
  share.clipboard) exec omarchy-menu-share clipboard ;;
  share.file) exec omarchy-launch-floating-terminal-with-presentation 'omarchy-menu-share file' ;;
  share.folder) exec omarchy-launch-floating-terminal-with-presentation 'omarchy-menu-share folder' ;;
  system.screensaver) exec omarchy-launch-screensaver force ;;
  system.lock) exec omarchy-system-lock ;;
  system.suspend) exec systemctl suspend ;;
  system.hibernate) exec systemctl hibernate ;;
  system.logout) exec omarchy-system-logout ;;
  system.restart) exec omarchy-system-reboot ;;
  system.shutdown) exec omarchy-system-shutdown ;;
  legacy.style.unlocks) exec omarchy-launch-walker -m menus:omarchyunlocks --width 800 --minheight 400 ;;
  legacy.style.background) exec omarchy-menu style ;;
  legacy.style.hyprland) exec omarchy-launch-editor "$HOME/.config/hypr/looknfeel.conf" ;;
  legacy.style.screensaver) exec omarchy-menu style ;;
  legacy.style.about) exec omarchy-menu style ;;
  legacy.setup.config) exec omarchy-menu setup ;;
  legacy.setup.security) exec omarchy-menu setup ;;
  legacy.*) exec omarchy-menu "${action#legacy.}" ;;
  *) printf 'Unknown or unavailable Quickshell menu action: %s\n' "$action" >&2; exit 64 ;;
esac
