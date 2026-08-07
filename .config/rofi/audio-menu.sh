#!/usr/bin/env bash
# Themed rofi audio-output picker (wpctl/PipeWire).
# Wired to the waybar pulseaudio widget (right-click), so the output can be
# changed from the bar without opening the dashboard or pavucontrol.
#
# The dashboard has the same switcher (DashMedia -> Audio.qml); this is the
# "I don't want to open anything" path.

THEME="$HOME/.config/rofi/theme.rasi"
rofi_menu() { rofi -dmenu -i -theme "$THEME" "$@"; }
note() { command -v notify-send > /dev/null 2>&1 && notify-send -a "Audio" "$@"; }

# `wpctl status` sink block. Lines look like:
#    │  *   51. AD107 ... (HDMI)            [vol: 1.00]
#    │      54. TUF GAMING H1 Wireless ...  [vol: 0.41]
# The leading '*' marks the current default. Node names can contain spaces and
# parentheses, so strip from the id to the volume field rather than splitting.
list=$(wpctl status 2> /dev/null | awk '
    /^ *├─ Sinks:/  { insink = 1; next }
    /^ *├─ Sources:/{ insink = 0 }
    !insink { next }
    /[0-9]+\./ {
        line = $0
        active = (line ~ /\*/) ? "\363\260\204\250 " : "  "      # 󰄨 on the current one
        sub(/.*[│|][ ]*\*?[ ]*/, "", line)                       # drop tree art + marker
        id = line; sub(/\..*/, "", id); gsub(/[^0-9]/, "", id)
        name = line; sub(/^[0-9]+\.[ ]*/, "", name)
        sub(/[ ]*\[vol:.*$/, "", name)                           # drop the volume column
        sub(/[ ]+$/, "", name)
        if (id == "" || name == "") next

        # icon by device class
        low = tolower(name)
        if (low ~ /hdmi|displayport/)                    ic = "\363\260\215\271"   # 󰍹 monitor
        else if (low ~ /wireless|headset|headphone|bluez/) ic = "\363\260\213\213" # 󰋋 headset
        else if (low ~ /easy ?effects/)                  ic = "\363\260\213\274"   # 󰋼 virtual
        else                                             ic = "\363\260\223\203"   # 󰓃 speakers

        printf "%s%s  %s\t%s\n", active, ic, name, id
    }')

[ -z "$list" ] && {
    note "No audio outputs found"
    exit 1
}

choice=$(printf '%s\n' "$list" | cut -f1 | rofi_menu -p "output" -mesg "switch audio output")
[ -z "$choice" ] && exit 0

# Map the chosen label back to its node id via the tab-separated second field.
id=$(printf '%s\n' "$list" | awk -F'\t' -v c="$choice" '$1 == c { print $2; exit }')
[ -z "$id" ] && exit 1

if wpctl set-default "$id" 2> /dev/null; then
    # Strip the marker/icon prefix for a cleaner notification.
    clean=$(printf '%s' "$choice" | sed 's/^[^ ]*  *[^ ]*  *//')
    note "Output switched" "$clean"
else
    note -u critical "Failed to switch output"
    exit 1
fi
