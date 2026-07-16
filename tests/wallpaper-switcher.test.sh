#!/usr/bin/env bash
set -euo pipefail
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
home="$tmp/home"
theme="$home/.config/omarchy/themes/Test Theme"
bundled="$theme/backgrounds"
user="$home/.config/omarchy/backgrounds/Test Theme"
mkdir -p "$bundled" "$user" "$home/.config/omarchy/current"
ln -s "$theme" "$home/.config/omarchy/current/theme"
ln -s "$bundled/01-first image.jpg" "$home/.config/omarchy/current/background"
for file in "01-first image.jpg" "2026.png" "abcdef0123456789abcdef0123456789.webp" "same.png" "anim.gif" "photo.bmp"; do : > "$bundled/$file"; done
: > "$user/same.png"
: > "$user/user wall.jpeg"
: > "$user/ignore.txt"

output="$(HOME="$home" XDG_CACHE_HOME="$home/.cache" bash "$repo/scripts/qs-wallpaper-switcher" list)"
grep -Fq "$bundled/01-first image.jpg" <<< "$output"
grep -Fq $'\tfirst image' <<< "$output"
grep -Fq $'2026.png\t2026' <<< "$output"
grep -Fq $'abcdef0123456789abcdef0123456789.webp\tWallpaper abcdef01' <<< "$output"
grep -Fq "$user/user wall.jpeg" <<< "$output"
grep -Fq "$bundled/anim.gif" <<< "$output"
grep -Fq "$bundled/photo.bmp" <<< "$output"
[[ "$(grep -c $'same.png\t' <<< "$output")" -eq 1 ]]
grep -Fq "$bundled/same.png" <<< "$output"
! grep -Fq "$user/same.png" <<< "$output"
cache="$(HOME="$home" XDG_CACHE_HOME="$home/.cache" bash "$repo/scripts/qs-wallpaper-switcher" cache)"
[[ "$cache" == "$output" ]]
current="$(HOME="$home" XDG_CACHE_HOME="$home/.cache" bash "$repo/scripts/qs-wallpaper-switcher" current)"
[[ "$current" == "$bundled/01-first image.jpg" ]]
printf 'ok (wallpaper switcher provider)\n'
