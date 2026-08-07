#!/usr/bin/env bash
# Super+W — rofi wallpaper picker (thumbnail grid).
# Sets the wallpaper via awww AND persists it: writes the chosen path to
# ~/.config/hypr/current-wallpaper, which the hyprland autostart reads on login.
set -u

# Both collections. ~/Pictures/Wallpapers is where the wallhaven downloads live;
# the picker used to scan only the catppuccin folder, so most of them were
# invisible to Super+W. Add more directories to this array freely.
WALL_DIRS=(
    "$HOME/Pictures/Wallpapers"
    "$HOME/Pictures/catppuccin-wallpapers"
)
STATE="$HOME/.config/hypr/current-wallpaper"
THEME="$HOME/.config/rofi/theme.rasi"

# Make sure the wallpaper daemon is running
pgrep -x awww-daemon >/dev/null 2>&1 || { setsid awww-daemon >/dev/null 2>&1 </dev/null & sleep 1; }

# Build a thumbnail grid in rofi (icon = the image itself).
# The rofi row shows only the basename but carries the FULL path as its icon,
# so after choosing we look the path back up rather than guessing a directory —
# names can repeat across folders (catppuccin-valley.jpg is in both).
mapfile -t files < <(
  find "${WALL_DIRS[@]}" -maxdepth 1 -type f \
       \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' \) \
       2>/dev/null | sort -u
)
[ "${#files[@]}" -eq 0 ] && exit 0

choice=$(
  for f in "${files[@]}"; do printf '%s\0icon\x1f%s\n' "${f##*/}" "$f"; done \
    | rofi -dmenu -i -show-icons -theme "$THEME" \
           -theme-str 'element-icon { size: 6em; } listview { columns: 4; lines: 3; } window { width: 70%; }' \
           -p "Wallpaper"
)
[ -z "$choice" ] && exit 0

sel=""
for f in "${files[@]}"; do
    if [ "${f##*/}" = "$choice" ]; then sel="$f"; break; fi
done
[ -n "$sel" ] && [ -f "$sel" ] || exit 1

if awww img --transition-type simple "$sel"; then
    printf '%s\n' "$sel" > "$STATE"
fi
