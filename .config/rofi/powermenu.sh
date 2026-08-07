#!/usr/bin/env bash
# Themed power menu (rofi) — lock / suspend / logout / reboot / shutdown.
#
# Glyphs are written as \U escapes rather than literal characters so this file
# stays editable in any editor and cannot be mangled by a tool that doesn't
# handle astral-plane codepoints.
set -uo pipefail

THEME="$HOME/.config/rofi/powermenu.rasi"

g() { printf "\\U000$1"; } # Nerd Font (Material Design) codepoint → glyph

LOCK="$(g F033E)"
SLEEP="$(g F0904)"
LOGOUT="$(g F0343)"
REBOOT="$(g F0709)"
POWER="$(g F0425)"

# Hyprland's own exit path; matches what SUPER+M already does.
logout_cmd() {
    if command -v hyprshutdown > /dev/null 2>&1; then
        hyprshutdown
    else
        hyprctl dispatch 'hl.dsp.exit()'
    fi
}

confirm() { # confirm <label>
    local choice
    choice=$(printf '%s  no\n%s  yes\n' "$(g F0156)" "$(g F012C)" \
        | rofi -dmenu -i -theme "$THEME" \
            -theme-str 'listview { lines: 2; } window { width: 260px; }' \
            -p "$1?" -l 2 -selected-row 0)
    [[ $choice == *yes* ]]
}

entries=$(
    printf '%s  lock\n' "$LOCK"
    printf '%s  suspend\n' "$SLEEP"
    printf '%s  logout\n' "$LOGOUT"
    printf '%s  reboot\n' "$REBOOT"
    printf '%s  shutdown\n' "$POWER"
)

sel=$(printf '%s' "$entries" | rofi -dmenu -i -theme "$THEME" -p "session" -l 5)
[[ -z $sel ]] && exit 0

case "$sel" in
    *lock)
        hyprlock
        ;;
    *suspend)
        # Lock first so the screen is already covered when it resumes.
        hyprlock & disown
        sleep 0.3
        systemctl suspend
        ;;
    *logout)
        confirm "log out" && logout_cmd
        ;;
    *reboot)
        confirm "reboot" && systemctl reboot
        ;;
    *shutdown)
        confirm "shut down" && systemctl poweroff
        ;;
esac
