#!/usr/bin/env bash
# Super+W — rofi wallpaper picker (thumbnail grid).
# Sets the wallpaper via awww AND persists it: writes the chosen path to
# ~/.config/hypr/current-wallpaper, which the hyprland autostart reads on login.
set -u

WALL_DIR="$HOME/Pictures/catppuccin-wallpapers"
STATE="$HOME/.config/hypr/current-wallpaper"
THEME="$HOME/.config/rofi/theme.rasi"

# Make sure the wallpaper daemon is running
pgrep -x awww-daemon >/dev/null 2>&1 || { setsid awww-daemon >/dev/null 2>&1 </dev/null & sleep 1; }

# Build a thumbnail grid in rofi (icon = the image itself)
choice=$(
  find "$WALL_DIR" -maxdepth 1 -type f \
       \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' \) \
    | sort \
    | while IFS= read -r f; do printf '%s\0icon\x1f%s\n' "${f##*/}" "$f"; done \
    | rofi -dmenu -i -show-icons -theme "$THEME" \
           -theme-str 'element-icon { size: 6em; } listview { columns: 4; lines: 3; } window { width: 70%; }' \
           -p "Wallpaper"
)
[ -z "$choice" ] && exit 0

sel="$WALL_DIR/$choice"
[ -f "$sel" ] || exit 1

if awww img --transition-type simple "$sel"; then
    printf '%s\n' "$sel" > "$STATE"
fi
