#!/usr/bin/env bash
# Quick-toggle backends for the waybar drawer group.
#   usage: toggles.sh <wifi|bt|dnd|night> <status|toggle>
#
# DND is owned by the Quickshell panel (it is the notification daemon), which
# mirrors its state into $STATE_DIR/dnd so waybar can render it without polling
# D-Bus. Everything else is queried from the real system tool.
set -uo pipefail

STATE_DIR="${XDG_RUNTIME_DIR:-/tmp}/rice"
mkdir -p "$STATE_DIR"

emit() { # emit <text> <class> <tooltip>
    printf '{"text":"%s","class":"%s","tooltip":"%s"}\n' "$1" "$2" "$3"
}

case "${1:-}" in

    wifi)
        case "${2:-status}" in
            toggle)
                if [[ $(nmcli -t radio wifi 2> /dev/null) == enabled ]]; then
                    nmcli radio wifi off
                else
                    nmcli radio wifi on
                fi
                ;;
            *)
                if [[ $(nmcli -t radio wifi 2> /dev/null) == enabled ]]; then
                    ssid=$(nmcli -t -f active,ssid dev wifi 2> /dev/null | awk -F: '$1=="yes"{print $2; exit}')
                    emit "󰤨" "on" "Wi-Fi on${ssid:+ — $ssid}"
                else
                    emit "󰤭" "off" "Wi-Fi off"
                fi
                ;;
        esac
        ;;

    bt)
        case "${2:-status}" in
            toggle)
                if bluetoothctl show 2> /dev/null | grep -q "Powered: yes"; then
                    bluetoothctl power off > /dev/null
                else
                    rfkill unblock bluetooth 2> /dev/null
                    bluetoothctl power on > /dev/null
                fi
                ;;
            *)
                if bluetoothctl show 2> /dev/null | grep -q "Powered: yes"; then
                    n=$(bluetoothctl devices Connected 2> /dev/null | grep -c '^Device' || true)
                    if ((n > 0)); then
                        emit "󰂱" "on" "Bluetooth on — $n connected"
                    else
                        emit "󰂯" "on" "Bluetooth on"
                    fi
                else
                    emit "󰂲" "off" "Bluetooth off"
                fi
                ;;
        esac
        ;;

    dnd)
        case "${2:-status}" in
            toggle) qs -c panel ipc call notifs toggleDnd > /dev/null 2>&1 ;;
            *)
                if [[ -r $STATE_DIR/dnd && $(< "$STATE_DIR/dnd") == 1 ]]; then
                    emit "󰂛" "on" "Do Not Disturb — on"
                else
                    emit "󰂚" "off" "Do Not Disturb — off"
                fi
                ;;
        esac
        ;;

    night)
        case "${2:-status}" in
            toggle)
                if pgrep -x gammastep > /dev/null; then
                    pkill -x gammastep
                else
                    # One-shot warm temperature; -P resets any prior ramp first.
                    setsid -f gammastep -P -O 4000 > /dev/null 2>&1
                fi
                ;;
            *)
                if pgrep -x gammastep > /dev/null; then
                    emit "󰖙" "on" "Night light — on (4000K)"
                else
                    emit "󰃝" "off" "Night light — off"
                fi
                ;;
        esac
        ;;

    # Always-visible connectivity indicator for the bar. Reuses the same tools
    # the other branches already depend on (nmcli / ip) — no new dependency.
    # Distinct from the `wifi` toggle above, which reports RADIO state; this
    # reports whether traffic can actually leave the machine.
    net)
        case "${2:-status}" in
            toggle) qs -c panel ipc call panel tab network > /dev/null 2>&1 ;;
            *)
                iface=$(ip route show default 2> /dev/null | awk '/^default/{print $5; exit}')

                if [[ -z ${iface:-} ]]; then
                    if [[ $(nmcli -t radio wifi 2> /dev/null) == disabled ]] \
                        && ! ls /sys/class/net | grep -qv '^lo$'; then
                        emit "󰀝" "airplane" "No radios enabled"
                    else
                        emit "󰤭" "disconnected" "Disconnected"
                    fi
                elif [[ -d /sys/class/net/$iface/wireless ]]; then
                    ssid=$(nmcli -t -f active,ssid dev wifi 2> /dev/null | awk -F: '$1=="yes"{print $2; exit}')
                    sig=$(nmcli -t -f active,signal dev wifi 2> /dev/null | awk -F: '$1=="yes"{print $2; exit}')
                    [[ -z $sig ]] && sig=0
                    # Four-step signal ramp so the glyph carries strength too.
                    if ((sig >= 75)); then
                        ico="󰤨"
                    elif ((sig >= 50)); then
                        ico="󰤥"
                    elif ((sig >= 25)); then
                        ico="󰤢"
                    else
                        ico="󰤟"
                    fi
                    emit "$ico" "wifi" "${ssid:-Wi-Fi} — ${sig}%"
                else
                    emit "󰈀" "ethernet" "Wired — $iface"
                fi
                ;;
        esac
        ;;

    *)
        echo "usage: $0 <wifi|bt|dnd|night|net> [status|toggle]" >&2
        exit 1
        ;;
esac
