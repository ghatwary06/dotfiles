#!/usr/bin/env bash
# Delayed full-monitor screenshot — for capturing things that VANISH when you
# reach for the mouse.
#
# The normal SUPER+SHIFT+S bind runs slurp, which needs a click-drag. Anything
# that depends on hover, focus, or an open menu dies the instant you start that
# drag: tooltips, hover-only affordances, the side panel closing on focus loss,
# rofi, right-click menus. No region selector can ever capture those.
#
# So this takes no input at all: it counts down, then grabs the whole focused
# monitor. Crop afterwards if you need to.
#
# Usage: screenshot-delayed.sh [seconds]   (default 5)

set -uo pipefail

DELAY=${1:-5}
DIR="$HOME/Pictures/Screenshots"
mkdir -p "$DIR"
OUT="$DIR/$(date +%Y%m%d-%H%M%S)-delayed.png"

# Replace the previous countdown toast instead of stacking five of them.
NID=99321

for ((i = DELAY; i > 0; i--)); do
    notify-send -a Screenshot -r "$NID" -t 1200 \
        "Screenshot in ${i}s" "Set up the screen — capturing the focused monitor"
    sleep 1
done

# Focused monitor, resolved at capture time rather than hardcoded: which screen
# is focused is exactly what changes between invocations.
MON=$(hyprctl -j monitors 2> /dev/null |
    python3 -c 'import json,sys
try:
    print(next(m["name"] for m in json.load(sys.stdin) if m.get("focused")))
except Exception:
    print("")' 2> /dev/null)

if [[ -n $MON ]]; then
    grim -o "$MON" "$OUT"
else
    grim "$OUT"   # fall back to the whole layout
fi

if [[ -s $OUT ]]; then
    wl-copy < "$OUT"
    notify-send -a Screenshot -r "$NID" -t 4000 \
        "Screenshot copied" "${MON:-all outputs} → clipboard & $(basename "$OUT")"
else
    notify-send -a Screenshot -r "$NID" -u critical "Screenshot failed" "grim produced no image"
fi
