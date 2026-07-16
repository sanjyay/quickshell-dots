#!/usr/bin/env bash
set -euo pipefail

# The menu itself is rendered and navigated by Quickshell.  This dispatcher is
# deliberately a closed action registry: it invokes Omarchy's backend helpers,
# never an upstream Walker menu UI.
action="${1:-}"

present() {
  exec omarchy-launch-floating-terminal-with-presentation "$1"
}

case "$action" in
  open-app-launcher) exec qs -c bar ipc call -- launcher open ;;
  open-about) exec omarchy-launch-about ;;

  learn-omarchy) exec omarchy-launch-webapp 'https://learn.omacom.io/2/the-omarchy-manual' ;;
  learn-hyprland) exec omarchy-launch-webapp 'https://wiki.hypr.land/' ;;
  learn-arch) exec omarchy-launch-webapp 'https://wiki.archlinux.org/title/Main_page' ;;
  learn-neovim) exec omarchy-launch-webapp 'https://www.lazyvim.org/keymaps' ;;
  learn-bash) exec omarchy-launch-webapp 'https://devhints.io/bash' ;;

  trigger-transcode) exec omarchy-transcode ;;
  capture-screenshot) exec omarchy-capture-screenshot ;;
  capture-screenrecord) exec omarchy-capture-screenrecording ;;
  capture-text) exec omarchy-capture-text-extraction ;;
  capture-color) exec bash -lc 'pkill hyprpicker 2>/dev/null || hyprpicker -a' ;;
  reminder-show) exec omarchy-reminder show ;;
  reminder-clear) exec omarchy-reminder clear ;;
  # Setting a reminder needs user-entered minutes/message input. Keep that
  # backend operation explicit and terminal-based; it never invokes a menu UI.
  reminder-set) present 'read -rp "Minutes: " minutes; [[ "$minutes" =~ ^[0-9]+$ ]] && omarchy-reminder "$minutes"' ;;
  share-clipboard) exec omarchy-menu-share clipboard ;;
  share-file) present 'omarchy-menu-share file' ;;
  share-folder) present 'omarchy-menu-share folder' ;;

  system-screensaver) exec omarchy-launch-screensaver force ;;
  system-lock) exec omarchy-system-lock ;;
  system-suspend) exec systemctl suspend ;;
  system-hibernate) exec systemctl hibernate ;;
  system-logout) exec omarchy-system-logout ;;
  system-restart) exec omarchy-system-reboot ;;
  system-shutdown) exec omarchy-system-shutdown ;;

  style-hyprland) exec omarchy-launch-editor "$HOME/.config/hypr/looknfeel.conf" ;;
  style-background) exec qs -c bar ipc call -- wallpaperSwitcher open ;;
  style-screensaver-edit-text|style-screensaver-set-from-image|style-screensaver-restore-default)
    printf 'Screensaver customization is handled by the installed Omarchy helper.\n' >&2
    exit 64
    ;;
  style-about-edit-text|style-about-set-from-image|style-about-restore-default)
    printf 'About customization is handled by the installed Omarchy helper.\n' >&2
    exit 64
    ;;

  setup-config-hyprland) exec omarchy-launch-editor "$HOME/.config/hypr/hyprland.conf" ;;
  setup-config-hypridle) present 'omarchy-launch-editor ~/.config/hypr/hypridle.conf && omarchy-restart-hypridle' ;;
  setup-config-hyprlock) exec omarchy-launch-editor "$HOME/.config/hypr/hyprlock.conf" ;;
  setup-config-hyprsunset) present 'omarchy-launch-editor ~/.config/hypr/hyprsunset.conf && omarchy-restart-hyprsunset' ;;
  setup-config-swayosd) present 'omarchy-launch-editor ~/.config/swayosd/config.toml && omarchy-restart-swayosd' ;;
  setup-config-walker) present 'omarchy-launch-editor ~/.config/walker/config.toml && omarchy-restart-walker' ;;
  setup-config-waybar) present 'omarchy-launch-editor ~/.config/waybar/config.jsonc && omarchy-restart-waybar' ;;
  setup-config-xcompose) present 'omarchy-launch-editor ~/.XCompose && omarchy-restart-xcompose' ;;
  setup-security-fingerprint) present omarchy-setup-security-fingerprint ;;
  setup-security-fido2) present omarchy-setup-security-fido2 ;;
  setup-audio) exec omarchy-launch-audio ;;
  setup-wifi) exec omarchy-launch-wifi ;;
  setup-bluetooth) exec omarchy-launch-bluetooth ;;
  setup-power-profile-performance) exec powerprofilesctl set performance ;;
  setup-power-profile-balanced) exec powerprofilesctl set balanced ;;
  setup-power-profile-power-saver) exec powerprofilesctl set power-saver ;;
  setup-system-sleep) exec omarchy-toggle-suspend ;;
  setup-monitors) exec omarchy-launch-editor "$HOME/.config/hypr/monitors.conf" ;;
  setup-keybindings) exec omarchy-launch-editor "$HOME/.config/hypr/bindings.conf" ;;
  setup-input) exec omarchy-launch-editor "$HOME/.config/hypr/input.conf" ;;
  setup-dns) present omarchy-setup-dns ;;
  setup-default-browser-*) present "omarchy-default-browser ${action#setup-default-browser-}" ;;
  setup-default-terminal-*) present "omarchy-default-terminal ${action#setup-default-terminal-}" ;;
  setup-default-editor-neovim) present 'omarchy-default-editor nvim' ;;
  setup-default-editor-vscode) present 'omarchy-default-editor code' ;;
  setup-default-editor-sublime) present 'omarchy-default-editor sublime_text' ;;
  setup-default-editor-*) present "omarchy-default-editor ${action#setup-default-editor-}" ;;

  install-package) present omarchy-pkg-install ;;
  install-aur) present omarchy-pkg-aur-install ;;
  install-web-app) present omarchy-webapp-install ;;
  install-tui) present omarchy-tui-install ;;
  install-windows) present 'omarchy-windows-vm install' ;;

  install-service-dropbox) present omarchy-install-dropbox ;;
  install-service-tailscale) present omarchy-install-tailscale ;;
  install-service-nordvpn) present omarchy-install-nordvpn ;;
  install-service-once) present omarchy-install-once ;;
  install-service-bitwarden) present 'omarchy-pkg-add bitwarden bitwarden-cli' ;;
  install-service-chromium-account) present omarchy-install-chromium-google-account ;;
  install-style-theme) present omarchy-theme-install ;;
  install-style-background) exec omarchy-theme-bg-install ;;
  install-style-font) printf 'Choose a font through the installed Omarchy font helper.\n' >&2; exit 64 ;;
  install-development-ruby-on-rails) present 'omarchy-install-dev-env ruby' ;;
  install-development-docker-db) present omarchy-install-docker-dbs ;;
  install-development-javascript) present 'omarchy-install-dev-env node' ;;
  install-development-go) present 'omarchy-install-dev-env go' ;;
  install-development-php) present 'omarchy-install-dev-env php' ;;
  install-development-python) present 'omarchy-install-dev-env python' ;;
  install-development-elixir) present 'omarchy-install-dev-env elixir' ;;
  install-development-zig) present 'omarchy-install-dev-env zig' ;;
  install-development-rust) present 'omarchy-install-dev-env rust' ;;
  install-development-java) present 'omarchy-install-dev-env java' ;;
  install-development-net) present 'omarchy-install-dev-env dotnet' ;;
  install-development-ocaml) present 'omarchy-install-dev-env ocaml' ;;
  install-development-clojure) present 'omarchy-install-dev-env clojure' ;;
  install-development-scala) present 'omarchy-install-dev-env scala' ;;
  install-editor-vscode) present omarchy-install-vscode ;;
  install-editor-cursor) present 'omarchy-pkg-add cursor-bin' ;;
  install-editor-zed) present omarchy-install-zed ;;
  install-editor-sublime-text) present 'omarchy-pkg-add sublime-text-4' ;;
  install-editor-helix) present omarchy-install-helix ;;
  install-editor-vim) present 'omarchy-pkg-add vim' ;;
  install-editor-emacs) present 'omarchy-pkg-add emacs-wayland' ;;
  install-terminal-alacritty|install-terminal-foot|install-terminal-ghostty|install-terminal-kitty)
    present "omarchy-install-terminal ${action#install-terminal-}"
    ;;
  install-browser-chrome) present 'omarchy-install-browser chrome' ;;
  install-browser-edge) present 'omarchy-install-browser edge' ;;
  install-browser-brave) present 'omarchy-install-browser brave' ;;
  install-browser-brave-origin) present 'omarchy-install-browser brave-origin' ;;
  install-browser-firefox) present 'omarchy-install-browser firefox' ;;
  install-browser-zen) present 'omarchy-install-browser zen' ;;
  install-ai-dictation) present omarchy-voxtype-install ;;
  install-ai-lm-studio) present 'omarchy-pkg-add lmstudio-bin' ;;
  install-ai-ollama) present 'omarchy-pkg-add ollama' ;;
  install-ai-crush) present 'omarchy-pkg-add crush-bin' ;;
  install-gaming-steam) present omarchy-install-gaming-steam ;;
  install-gaming-retroarch) present omarchy-install-gaming-retroarch ;;
  install-gaming-minecraft) present 'omarchy-pkg-add minecraft-launcher' ;;
  install-gaming-nvidia-geforce-now) present omarchy-install-gaming-geforce-now ;;
  install-gaming-xbox-cloud-gaming) present omarchy-install-gaming-xbox-cloud ;;
  install-gaming-xbox-controller) present omarchy-install-gaming-xbox-controllers ;;
  install-gaming-moonlight) present omarchy-install-gaming-moonlight ;;
  install-gaming-lutris) present omarchy-install-gaming-lutris ;;
  install-gaming-heroic) present omarchy-install-gaming-heroic ;;

  remove-development-ruby-on-rails) present 'omarchy-remove-dev-env ruby' ;;
  remove-development-javascript) present 'omarchy-remove-dev-env node' ;;
  remove-development-net) present 'omarchy-remove-dev-env dotnet' ;;
  remove-development-*) present "omarchy-remove-dev-env ${action#remove-development-}" ;;
  remove-package) present omarchy-pkg-remove ;;
  remove-web-app) present omarchy-webapp-remove ;;
  remove-tui) present omarchy-tui-remove ;;
  remove-windows) present 'omarchy-windows-vm remove' ;;
  remove-preinstalls) present omarchy-remove-preinstalls ;;
  remove-dictation) present omarchy-voxtype-remove ;;
  remove-browser-*) present "omarchy-remove-browser ${action#remove-browser-}" ;;
  remove-gaming-steam) present omarchy-remove-gaming-steam ;;
  remove-gaming-retroarch) present omarchy-remove-gaming-retroarch ;;
  remove-gaming-minecraft) present omarchy-remove-gaming-minecraft ;;
  remove-gaming-nvidia-geforce-now) present omarchy-remove-gaming-geforce-now ;;
  remove-gaming-xbox-cloud-gaming) present omarchy-remove-gaming-xbox-cloud ;;
  remove-gaming-xbox-controller) present omarchy-remove-gaming-xbox-controllers ;;
  remove-gaming-moonlight) present omarchy-remove-gaming-moonlight ;;
  remove-gaming-lutris) present omarchy-remove-gaming-lutris ;;
  remove-gaming-heroic) present omarchy-remove-gaming-heroic ;;

  update-channel-stable|update-channel-rc|update-channel-edge|update-channel-dev)
    present "omarchy-channel-set ${action#update-channel-}"
    ;;
  update-process-hypridle) exec omarchy-restart-hypridle ;;
  update-process-hyprsunset) exec omarchy-restart-hyprsunset ;;
  update-process-mako) exec omarchy-restart-mako ;;
  update-process-swayosd) exec omarchy-restart-swayosd ;;
  update-process-walker) exec omarchy-restart-walker ;;
  update-process-waybar) exec omarchy-restart-waybar ;;
  update-config-hyprland) present omarchy-refresh-hyprland ;;
  update-config-hypridle) present omarchy-refresh-hypridle ;;
  update-config-hyprlock) present omarchy-refresh-hyprlock ;;
  update-config-hyprsunset) present omarchy-refresh-hyprsunset ;;
  update-config-plymouth) present omarchy-refresh-plymouth ;;
  update-config-swayosd) present omarchy-refresh-swayosd ;;
  update-config-tmux) present omarchy-refresh-tmux ;;
  update-config-walker) present omarchy-refresh-walker ;;
  update-config-waybar) present omarchy-refresh-waybar ;;
  update-hardware-audio) exec omarchy-restart-pipewire ;;
  update-hardware-wi-fi) exec omarchy-restart-wifi ;;
  update-hardware-bluetooth) exec omarchy-restart-bluetooth ;;
  update-hardware-trackpad) exec omarchy-restart-trackpad ;;
  update-omarchy) present omarchy-update ;;
  update-extra-themes) present omarchy-theme-update ;;
  update-firmware) present omarchy-update-firmware ;;
  update-password) present passwd ;;
  update-timezone) present omarchy-tz-select ;;
  update-time) present omarchy-update-time ;;
  *)
    printf 'Unknown or unavailable Quickshell menu action: %s\n' "$action" >&2
    exit 64
    ;;
esac
