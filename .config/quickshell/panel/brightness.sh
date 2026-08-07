#!/usr/bin/env bash
# Brightness for both displays. The two panels need completely different
# mechanisms and behave nothing alike:
#
#   laptop (eDP-1)      /sys/class/backlight via brightnessctl   ~2ms
#   external (ViewSonic) DDC/CI over i2c via ddcutil             ~1000ms
#
# ddcutil is a THOUSAND times slower. That is not a tuning detail, it is the
# whole design: the UI must debounce the external slider and must never let two
# writes overlap, or dragging it queues seconds of lag onto the i2c bus.
#
# Both paths work as the normal user — `video` group for the backlight, and the
# i2c nodes are already accessible. No root, no polkit.
#
# Usage:
#   brightness.sh get                 -> "laptop=<0-100> external=<0-100|->"
#   brightness.sh set laptop   <0-100>
#   brightness.sh set external <0-100>

set -uo pipefail

# ddcutil talks to a specific display number; resolve it once rather than
# hardcoding, since --display numbering follows detection order.
DDC_DISPLAY=1
LOCK="${XDG_RUNTIME_DIR:-/tmp}/qs-brightness.lock"

ddc() { timeout 20 ddcutil --display "$DDC_DISPLAY" --sleep-multiplier .3 "$@" 2> /dev/null; }

get_laptop() {
    local line
    line=$(brightnessctl -m 2> /dev/null | head -1) || return 1
    # machine-readable: name,class,current,percent,max
    printf '%s' "${line}" | cut -d, -f4 | tr -d '%'
}

get_external() {
    local out
    out=$(ddc getvcp 10) || {
        printf '%s' '-'
        return
    }
    # "VCP code 0x10 (Brightness): current value = 100, max value = 100"
    printf '%s' "$out" | sed -n 's/.*current value = *\([0-9]\+\).*/\1/p' | head -1
}

case "${1:-get}" in
    get)
        l=$(get_laptop)
        e=$(get_external)
        printf 'laptop=%s external=%s\n' "${l:-0}" "${e:--}"
        ;;

    set)
        target=${2:-}
        val=${3:-}
        [[ $val =~ ^[0-9]+$ ]] || {
            echo "bad value: $val" >&2
            exit 2
        }
        ((val < 0)) && val=0
        ((val > 100)) && val=100

        case "$target" in
            laptop)
                # 0% on a laptop panel is a black screen you cannot read to fix,
                # so the floor is 1.
                ((val < 1)) && val=1
                brightnessctl -q set "${val}%"
                ;;
            external)
                # flock serialises writes: without it a fast drag starts a second
                # ddcutil while the first still holds the bus, and they corrupt
                # each other's transactions. -n means "give up rather than
                # queue" — a stale value is pointless once the user has moved on.
                exec 9> "$LOCK"
                flock -n 9 || exit 0
                ddc setvcp 10 "$val" > /dev/null
                ;;
            *)
                echo "unknown display: $target" >&2
                exit 2
                ;;
        esac
        ;;

    *)
        echo "usage: brightness.sh get | set <laptop|external> <0-100>" >&2
        exit 2
        ;;
esac
