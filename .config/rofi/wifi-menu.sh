#!/usr/bin/env bash
# Themed rofi Wi-Fi picker (nmcli) — matches the catppuccin rofi theme.
# Wired to the waybar network widget (on-click).

THEME="$HOME/.config/rofi/theme.rasi"
rofi_menu() { rofi -dmenu -i -theme "$THEME" "$@"; }
note() { command -v notify-send >/dev/null 2>&1 && notify-send -a "Wi-Fi" "$@"; }

# Make sure the radio is on
if [ "$(nmcli -g WIFI radio 2>/dev/null)" = "disabled" ]; then
    nmcli radio wifi on
    sleep 2
fi

nmcli device wifi rescan >/dev/null 2>&1 || true
sleep 1

# Build the network list. Format: "<signal-icon><lock>  <SSID>"
# Active network gets a ● marker inside the icon group so SSID extraction stays clean.
list=$(nmcli -t -f IN-USE,SIGNAL,SECURITY,SSID device wifi list 2>/dev/null \
  | awk -F: '
    $4=="" { next }
    {
      active = ($1 == "*") ? "\357\204\207 " : ""        # nf check on active
      sig = $2; sec = $3; ssid = $4
      if      (sig >= 75) w = "\363\260\244\250"          # 󰤨
      else if (sig >= 50) w = "\363\260\244\245"          # 󰤥
      else if (sig >= 25) w = "\363\260\244\242"          # 󰤢
      else                w = "\363\260\244\237"          # 󰤟
      lock = (sec == "" || sec == "--") ? "" : " \363\260\214\207"   # 󰌇
      printf "%s%s%s  %s\n", active, w, lock, ssid
    }' \
  | awk '!seen[$0]++')

# Prepend a rescan action
menu=$(printf "\363\260\221\204  Rescan\n%s" "$list")

chosen=$(printf "%s" "$menu" | rofi_menu -p "Wi-Fi")
[ -z "$chosen" ] && exit 0

# Rescan option
case "$chosen" in
    *"Rescan") exec "$0" ;;
esac

# SSID is everything after the double-space that separates icons from the name
ssid="${chosen#*  }"
[ -z "$ssid" ] && exit 0

# Already have a saved connection? just bring it up
if nmcli -t -f NAME connection show 2>/dev/null | grep -Fxq "$ssid"; then
    if nmcli connection up id "$ssid" >/dev/null 2>&1; then
        note "Connected to $ssid"
    else
        note "Failed to connect to $ssid"
    fi
    exit 0
fi

# New network — figure out if it needs a password
sec=$(nmcli -t -f SSID,SECURITY device wifi list 2>/dev/null \
      | awk -F: -v s="$ssid" '$1==s {print $2; exit}')

if [ -n "$sec" ] && [ "$sec" != "--" ]; then
    pass=$(printf "" | rofi -dmenu -password -theme "$THEME" -p "Password for $ssid")
    [ -z "$pass" ] && exit 0
    if nmcli device wifi connect "$ssid" password "$pass" >/dev/null 2>&1; then
        note "Connected to $ssid"
    else
        note "Failed to connect to $ssid (wrong password?)"
    fi
else
    if nmcli device wifi connect "$ssid" >/dev/null 2>&1; then
        note "Connected to $ssid"
    else
        note "Failed to connect to $ssid"
    fi
fi
