#!/usr/bin/env bash
# Transport button flanking the mpris module. Prints its glyph only while a
# player actually exists, so with nothing playing the whole media cluster
# collapses instead of leaving two orphaned arrows in the centre of the bar.
set -uo pipefail

status=$(playerctl status 2> /dev/null)
[[ -z $status ]] && exit 0

case "${1:-}" in
    prev) printf '\U000F04AE\n' ;; # skip-previous
    next) printf '\U000F04AD\n' ;; # skip-next
    sep) printf '\U02502\n' ;;     # box-drawing rule between weather and media
    *) exit 1 ;;
esac
