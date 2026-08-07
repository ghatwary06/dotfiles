#!/usr/bin/env bash
# Notification-center button. The Quickshell panel is the notification daemon;
# it writes the unread count and DND flag into $STATE_DIR, which is all this
# needs to render. Signal-driven (waybar signal 8) plus a slow interval as a
# safety net in case a signal is missed.
set -uo pipefail

STATE_DIR="${XDG_RUNTIME_DIR:-/tmp}/rice"

count=0
[[ -r $STATE_DIR/notif-count ]] && count=$(< "$STATE_DIR/notif-count")
[[ $count =~ ^[0-9]+$ ]] || count=0

dnd=0
[[ -r $STATE_DIR/dnd ]] && dnd=$(< "$STATE_DIR/dnd")

if [[ $dnd == 1 ]]; then
    printf '{"text":"󰂛","class":"dnd","tooltip":"Do Not Disturb — %s held"}\n' "$count"
elif ((count > 0)); then
    printf '{"text":"󰂚 %s","class":"unread","tooltip":"%s notification(s)"}\n' "$count" "$count"
else
    printf '{"text":"󰂜","class":"empty","tooltip":"No notifications"}\n'
fi
