#!/usr/bin/env bash
# The ONLY thing in the panel that changes machine state. SecPower.qml calls
# this; sysinfo.sh is strictly read-only.
#
# Everything here works as the normal user — no polkit prompt, no sudo:
#   * powerprofilesctl talks to power-profiles-daemon over D-Bus
#   * asusctl talks to asusd, which holds the privilege
# A panel button can never answer a password dialog, so anything needing root
# is deliberately NOT exposed here (see "charge limit" at the bottom).
#
# Usage:
#   powerctl.sh profile <power-saver|balanced|performance>
#   powerctl.sh armoury <attr> <value>
#   powerctl.sh kbd     <off|low|med|high|next>
# Exit status is what the caller reports in the panel, so failures must NOT be
# swallowed.

set -uo pipefail

cmd=${1:-}
shift || true

case "$cmd" in
    profile)
        want=${1:-}
        # power-profiles-daemon OWNS /sys/firmware/acpi/platform_profile. Driving
        # `asusctl profile` as well would mean two daemons fighting over one knob,
        # so the panel goes through ppd exclusively.
        case "$want" in
            power-saver | balanced | performance) ;;
            *)
                echo "bad profile: $want" >&2
                exit 2
                ;;
        esac
        exec powerprofilesctl set "$want"
        ;;

    armoury)
        attr=${1:-}
        val=${2:-}
        # Whitelist. These are the knobs the panel is allowed to touch — notably
        # NOT gpu_mux_mode or dgpu_disable: both need a reboot to take effect and
        # a mis-click there can leave the machine with no working display.
        case "$attr" in
            ppt_pl1_spl | ppt_pl2_sppt | nv_dynamic_boost | nv_temp_target | panel_overdrive) ;;
            *)
                echo "refusing to set: $attr" >&2
                exit 2
                ;;
        esac
        [[ $val =~ ^[0-9]+$ ]] || {
            echo "bad value: $val" >&2
            exit 2
        }
        # asusctl prints a "Multiple asusd interfaces devices found" notice to
        # stdout even on success; only the exit status is meaningful.
        asusctl armoury set "$attr" "$val" > /dev/null 2>&1
        exit $?
        ;;

    kbd)
        want=${1:-next}
        case "$want" in
            off | low | med | high) asusctl leds set "$want" > /dev/null 2>&1 ;;
            next) asusctl leds next > /dev/null 2>&1 ;;
            *)
                echo "bad kbd level: $want" >&2
                exit 2
                ;;
        esac
        exit $?
        ;;

    *)
        cat >&2 << 'USAGE'
usage: powerctl.sh profile <power-saver|balanced|performance>
       powerctl.sh armoury <attr> <value>
       powerctl.sh kbd     <off|low|med|high|next>

NOT supported on purpose:
  charge limit  /sys/class/power_supply/BAT0/charge_control_end_threshold is
                root-owned and this asusctl build has no charge subcommand, so
                the panel DISPLAYS it and does not pretend it can change it.
                Changing it would need a polkit rule or a sudoers entry.
  gpu_mux_mode  needs a reboot; a wrong click can black-screen the machine.
  dgpu_disable  same.
USAGE
        exit 2
        ;;
esac
