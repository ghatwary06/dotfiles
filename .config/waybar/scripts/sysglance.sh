#!/usr/bin/env bash
# Compact CPU / RAM / GPU glance. Click opens the Quickshell side panel on its
# system tab. GPU comes from nvidia-smi (RTX 4050); if the dGPU is asleep or the
# driver is unloaded the field degrades to "--" instead of breaking the module.
set -euo pipefail

CACHE="${XDG_RUNTIME_DIR:-/tmp}/waybar-sysglance"

# --- CPU: busy vs total jiffies since the last sample ------------------------
read -r _ user nice system idle iowait irq softirq steal _ < /proc/stat
idle_all=$((idle + iowait))
total=$((user + nice + system + idle_all + irq + softirq + steal))

prev_total=0 prev_idle=0
[[ -r $CACHE ]] && read -r prev_total prev_idle < "$CACHE" || true
printf '%s %s\n' "$total" "$idle_all" > "$CACHE"

dt=$((total - prev_total))
di=$((idle_all - prev_idle))
if ((dt > 0)); then
    cpu=$(((dt - di) * 100 / dt))
else
    cpu=0
fi
((cpu < 0)) && cpu=0
((cpu > 100)) && cpu=100

# --- RAM: MemAvailable is the honest "free" number ---------------------------
mem_total=$(awk '/^MemTotal:/ {print $2; exit}' /proc/meminfo)
mem_avail=$(awk '/^MemAvailable:/ {print $2; exit}' /proc/meminfo)
mem=$(((mem_total - mem_avail) * 100 / mem_total))
mem_used_gb=$(awk -v u=$((mem_total - mem_avail)) 'BEGIN {printf "%.1f", u/1048576}')
mem_total_gb=$(awk -v t="$mem_total" 'BEGIN {printf "%.1f", t/1048576}')

# --- GPU ---------------------------------------------------------------------
gpu="--" gputemp="--" vram="--"
if command -v nvidia-smi > /dev/null 2>&1; then
    if read -r gpu gputemp vmem vtotal < <(
        nvidia-smi --query-gpu=utilization.gpu,temperature.gpu,memory.used,memory.total \
            --format=csv,noheader,nounits 2>/dev/null | tr -d ',' | head -1
    ); then
        vram="${vmem}/${vtotal}MiB"
    else
        gpu="--" gputemp="--"
    fi
fi
[[ -z ${gpu:-} ]] && gpu="--"

# --- CPU temp (best effort, for the tooltip only) ----------------------------
cputemp="--"
for z in /sys/class/thermal/thermal_zone*/; do
    [[ -r ${z}type && -r ${z}temp ]] || continue
    case "$(< "${z}type")" in
        x86_pkg_temp | coretemp | acpitz)
            cputemp=$(($(< "${z}temp") / 1000))
            break
            ;;
    esac
done

class=idle
((cpu >= 80 || mem >= 85)) && class=high
[[ $gpu != "--" ]] && ((gpu >= 80)) && class=high

# --- per-metric colouring ----------------------------------------------------
# Each metric owns a hue (identity) but escalates to amber/red on its own
# (state), so a pegged CPU is obvious even while RAM and GPU stay calm.
# Keep these in sync with @m_cpu / @m_ram / @m_gpu in waybar/colors.css.
C_CPU="#81A1C1"
C_RAM="#B48EAD"
C_GPU="#A3BE8C"
C_WARN="#EBCB8B"
C_CRIT="#BF616A"

hue() { # hue <value> <base-colour>  -> colour for that reading
    local v=$1 base=$2
    if ((v >= 90)); then
        printf '%s' "$C_CRIT"
    elif ((v >= 75)); then
        printf '%s' "$C_WARN"
    else
        printf '%s' "$base"
    fi
}

span() { # span <colour> <text>
    printf '<span color=\\"%s\\">%s</span>' "$1" "$2"
}

text="$(span "$(hue "$cpu" "$C_CPU")" "$(printf '󰘚 %02d%%' "$cpu")")"
text="$text  $(span "$(hue "$mem" "$C_RAM")" "$(printf '󰍛 %02d%%' "$mem")")"
if [[ $gpu != "--" ]]; then
    text="$text  $(span "$(hue "$gpu" "$C_GPU")" "$(printf '󰢮 %02d%%' "$gpu")")"
fi

tooltip="CPU  ${cpu}%  ${cputemp}°C\rRAM  ${mem}%  ${mem_used_gb}/${mem_total_gb} GiB\rGPU  ${gpu}%  ${gputemp}°C  ${vram}\r\rclick → open system panel"

printf '{"text":"%s","tooltip":"%s","class":"%s"}\n' "$text" "$tooltip" "$class"
