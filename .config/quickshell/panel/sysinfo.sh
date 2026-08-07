#!/usr/bin/env bash
# One-shot system snapshot as JSON, consumed by the Quickshell side panel.
# Deliberately a single process per tick (rather than a handful) so opening the
# panel does not fan out into a dozen forks every two seconds.
set -uo pipefail

CACHE="${XDG_RUNTIME_DIR:-/tmp}/qs-panel-cpu"

# --- CPU: aggregate + per-core, delta against the previous tick --------------
declare -A cur_total cur_idle
while read -r cpu user nice system idle iowait irq softirq steal _; do
    [[ $cpu == cpu* ]] || continue
    ia=$((idle + iowait))
    cur_idle[$cpu]=$ia
    cur_total[$cpu]=$((user + nice + system + ia + irq + softirq + steal))
done < <(grep '^cpu' /proc/stat)

declare -A prev_total prev_idle
if [[ -r $CACHE ]]; then
    while read -r k t i; do
        prev_total[$k]=$t
        prev_idle[$k]=$i
    done < "$CACHE"
fi

: > "$CACHE"
for k in "${!cur_total[@]}"; do
    printf '%s %s %s\n' "$k" "${cur_total[$k]}" "${cur_idle[$k]}" >> "$CACHE"
done

pct_for() { # pct_for <cpu key>
    local k=$1 dt di
    dt=$((${cur_total[$k]:-0} - ${prev_total[$k]:-0}))
    di=$((${cur_idle[$k]:-0} - ${prev_idle[$k]:-0}))
    if ((dt > 0)); then
        local p=$(((dt - di) * 100 / dt))
        ((p < 0)) && p=0
        ((p > 100)) && p=100
        echo "$p"
    else
        echo 0
    fi
}

cpu=$(pct_for cpu)

cores=""
for k in $(printf '%s\n' "${!cur_total[@]}" | grep -x 'cpu[0-9]\+' | sort -V); do
    cores+="$(pct_for "$k"),"
done
cores="[${cores%,}]"

# --- CPU temp ----------------------------------------------------------------
cputemp=0
for z in /sys/class/thermal/thermal_zone*/; do
    [[ -r ${z}type && -r ${z}temp ]] || continue
    case "$(< "${z}type")" in
        x86_pkg_temp | coretemp | acpitz)
            cputemp=$(($(< "${z}temp") / 1000))
            break
            ;;
    esac
done
# k10temp/coretemp via hwmon is more accurate when present
for h in /sys/class/hwmon/hwmon*/; do
    [[ -r ${h}name ]] || continue
    case "$(< "${h}name")" in
        coretemp | k10temp | zenpower)
            [[ -r ${h}temp1_input ]] && cputemp=$(($(< "${h}temp1_input") / 1000))
            break
            ;;
    esac
done

# --- memory / swap -----------------------------------------------------------
mem_total=$(awk '/^MemTotal:/{print $2;exit}' /proc/meminfo)
mem_avail=$(awk '/^MemAvailable:/{print $2;exit}' /proc/meminfo)
swap_total=$(awk '/^SwapTotal:/{print $2;exit}' /proc/meminfo)
swap_free=$(awk '/^SwapFree:/{print $2;exit}' /proc/meminfo)
mem_used=$((mem_total - mem_avail))
swap_used=$((swap_total - swap_free))
mem_pct=$((mem_total > 0 ? mem_used * 100 / mem_total : 0))
swap_pct=$((swap_total > 0 ? swap_used * 100 / swap_total : 0))

# --- GPU (NVIDIA RTX 4050) ---------------------------------------------------
gpu_present=false
gpu=0 gpu_temp=0 vram_used=0 vram_total=0 gpu_power=0 gpu_name=""
if command -v nvidia-smi > /dev/null 2>&1; then
    line=$(nvidia-smi --query-gpu=name,utilization.gpu,temperature.gpu,memory.used,memory.total,power.draw \
        --format=csv,noheader,nounits 2> /dev/null | head -1)
    if [[ -n $line ]]; then
        IFS=',' read -r gpu_name gpu gpu_temp vram_used vram_total gpu_power <<< "$line"
        gpu_name=$(echo "$gpu_name" | sed 's/^ *//;s/ *$//;s/NVIDIA //')
        for v in gpu gpu_temp vram_used vram_total; do
            val=$(echo "${!v}" | tr -dc '0-9')
            printf -v "$v" '%s' "${val:-0}"
        done
        gpu_power=$(echo "$gpu_power" | tr -dc '0-9.')
        [[ -z $gpu_power ]] && gpu_power=0
        gpu_present=true
    fi
fi

# --- power / battery / fans / firmware knobs ---------------------------------
# Everything here is READ-ONLY. Writes go through SecPower.qml -> powerctl.sh,
# so there is exactly one place that can change machine state.

# Read a sysfs file, or a default if it is missing/unreadable/empty.
# NB: `$(< file)` is a bash special form that accepts NOTHING but the filename —
# writing `$(< file 2>/dev/null || echo 0)` turns it into a command substitution
# with no command, which silently yields an EMPTY string and blows up the
# surrounding $(( )) with "operand expected".
rd() {
    local v=""
    [[ -r $1 ]] && v=$(cat "$1" 2> /dev/null)
    [[ -n $v ]] && printf '%s' "$v" || printf '%s' "${2:-0}"
}

# Fans: resolve the hwmon by NAME, never by hwmonN — those numbers are assigned
# in probe order and shuffle between boots exactly like /dev/dri/cardN does.
fan_cpu=0 fan_gpu=0
for h in /sys/class/hwmon/hwmon*/; do
    [[ $(rd "${h}name" none) == asus ]] || continue
    for f in "$h"fan*_input; do
        [[ -r $f ]] || continue
        case "$(rd "${f%_input}_label" none)" in
            cpu_fan) fan_cpu=$(rd "$f") ;;
            gpu_fan) fan_gpu=$(rd "$f") ;;
        esac
    done
    break
done

# Battery. energy_* is in µWh and power_now in µW; both are scaled to
# centi-units here so the JSON stays integer and the QML divides by 100.
bat_present=false
bat_pct=0 bat_status="" bat_energy=0 bat_full=0 bat_design=0 bat_draw=0 bat_limit=0 bat_cycles=0
for b in /sys/class/power_supply/BAT*/; do
    [[ -r ${b}capacity ]] || continue
    bat_present=true
    bat_pct=$(rd "${b}capacity")
    bat_status=$(rd "${b}status" unknown)
    bat_energy=$(( $(rd "${b}energy_now") / 10000 ))       # → cWh
    bat_full=$((   $(rd "${b}energy_full") / 10000 ))
    bat_design=$(( $(rd "${b}energy_full_design") / 10000 ))
    bat_draw=$((   $(rd "${b}power_now") / 10000 ))        # → cW
    bat_limit=$(rd "${b}charge_control_end_threshold")
    bat_cycles=$(rd "${b}cycle_count")
    break
done

ac_online=0
for a in /sys/class/power_supply/A{C,DP}*/; do
    [[ -r ${a}online ]] && ac_online=$(rd "${a}online") && break
done

# Active power profile (power-profiles-daemon owns platform_profile; asusctl
# must NOT also drive it or the two fight over the same knob).
pprofile=$(powerprofilesctl get 2> /dev/null | tr -d '[:space:]')
[[ -z $pprofile ]] && pprofile=$(< /sys/firmware/acpi/platform_profile 2> /dev/null)

# asus-armoury firmware attributes, straight from sysfs — far cheaper than
# shelling out to asusctl once per attribute.
AA=/sys/class/firmware-attributes/asus-armoury/attributes
aa() { rd "$AA/$1/current_value"; }
ppt_pl1=$(aa ppt_pl1_spl)
ppt_pl2=$(aa ppt_pl2_sppt)
nv_boost=$(aa nv_dynamic_boost)
nv_temp=$(aa nv_temp_target)
mux_mode=$(aa gpu_mux_mode)
dgpu_off=$(aa dgpu_disable)
reboot_pending=$(rd /sys/class/firmware-attributes/asus-armoury/pending_reboot)

kbd_led=$(rd /sys/class/leds/asus::kbd_backlight/brightness)
kbd_led_max=$(rd /sys/class/leds/asus::kbd_backlight/max_brightness 3)

# --- load / uptime -----------------------------------------------------------
read -r l1 l5 l15 _ < /proc/loadavg
up=$(awk '{printf "%d", $1}' /proc/uptime)
up_str=$(printf '%dd %dh %dm' $((up / 86400)) $((up % 86400 / 3600)) $((up % 3600 / 60)))

# --- process table -----------------------------------------------------------
# CPU% is computed as a DELTA between ticks, the way top/htop do it.
#
# This used to be `ps -eo pcpu`, which is WRONG for a live monitor: ps reports a
# process's average CPU over its ENTIRE LIFETIME. A browser open for six hours
# shows ~2% while it is pegging a core right now, and a process that started a
# second ago shows a wildly inflated number. Neither reflects "what is using my
# CPU", which is the only question this table exists to answer.
#
# So: cache utime+stime per pid, and divide the delta by elapsed wall time.
#   cpu% = 100 * ((ticks_now - ticks_prev) / CLK_TCK) / seconds_elapsed
# This is per-CORE-normalised like top's default (Irix mode): a process using
# two cores fully reads 200%. `cpuNorm` in the JSON is the same figure divided
# by core count, for callers that want a 0-100 share-of-machine reading.
#
# Elapsed time comes from /proc/uptime rather than date(1): it is monotonic, so
# an NTP step or a suspend/resume cannot produce a negative or absurd delta.
PROC_CACHE="${XDG_RUNTIME_DIR:-/tmp}/qs-panel-procs"
CLK=$(getconf CLK_TCK 2> /dev/null || echo 100)
PAGE=$(getconf PAGESIZE 2> /dev/null || echo 4096)
NCPU=$(nproc 2> /dev/null || echo 1)
read -r now_up _ < /proc/uptime

# One awk process walks every /proc/<pid>/stat and emits TSV. Doing this in a
# bash loop would be ~400 subshell-free reads but still far slower, and forking
# per pid (stat/awk/tr) would be an order of magnitude worse.
proc_tsv=$(
    awk -v cache="$PROC_CACHE" -v now="$now_up" -v clk="$CLK" \
        -v page="$PAGE" -v ncpu="$NCPU" '
    BEGIN {
        prev_up = -1
        while ((getline line < cache) > 0) {
            split(line, a, " ")
            if (a[1] == "#") { prev_up = a[2] + 0; continue }
            prev[a[1] + 0] = a[2] + 0
        }
        close(cache)
        dt = (prev_up >= 0) ? now - prev_up : 0
        if (dt < 0) dt = 0           # monotonic, but be defensive

        # uid -> name, read once instead of forking id(1) per process
        while ((getline line < "/etc/passwd") > 0) {
            split(line, p, ":")
            uname[p[3] + 0] = p[1]
        }
        close("/etc/passwd")
    }
    {
        # /proc/<pid>/stat is "pid (comm) state ...". comm is unquoted and may
        # contain spaces AND parentheses ("Web Content (tab)"), so the only safe
        # split is: first "(" and LAST ")".
        line = $0
        op = index(line, "(")
        cp = 0
        for (i = length(line); i > 1; i--)
            if (substr(line, i, 1) == ")") { cp = i; break }
        if (op == 0 || cp == 0) next

        pid  = substr(line, 1, op - 2) + 0
        comm = substr(line, op + 1, cp - op - 1)
        nf   = split(substr(line, cp + 2), f, " ")
        if (nf < 22) next
        # f[] is offset by 2 from the documented field numbers, since "pid" and
        # "(comm)" were consumed above: utime(14)=f[12], stime(15)=f[13],
        # nice(19)=f[17], num_threads(20)=f[18], rss(24)=f[22].
        state   = f[1]
        ppid    = f[2] + 0
        ticks   = f[12] + f[13]
        nice    = f[17] + 0
        threads = f[18] + 0
        rss     = f[22] + 0

        cpu = 0
        if (dt > 0 && (pid in prev)) {
            d = ticks - prev[pid]
            if (d > 0) cpu = 100 * (d / clk) / dt
        }
        # A pid can be recycled onto a different process; a nonsense delta is
        # the tell. Clamp rather than emit a 4000% row.
        if (cpu > 100 * ncpu) cpu = 100 * ncpu

        # owner, from the matching status file (same awk process, no fork)
        uid = -1
        sf = FILENAME
        sub(/stat$/, "status", sf)
        while ((getline sl < sf) > 0)
            if (substr(sl, 1, 4) == "Uid:") { split(sl, u, /[ \t]+/); uid = u[2] + 0; break }
        close(sf)
        who = (uid in uname) ? uname[uid] : (uid >= 0 ? uid : "?")

        newcache = newcache pid " " ticks "\n"
        printf "%d\t%.2f\t%.1f\t%s\t%d\t%d\t%d\t%s\t%s\n", \
               pid, cpu, rss * page / 1048576, state, ppid, threads, nice, who, comm
    }
    END {
        printf "# %s\n%s", now, newcache > cache
    }
    ' /proc/[0-9]*/stat 2> /dev/null
)

# Per-process GPU memory. One nvidia-smi call.
#
# NOT --query-compute-apps: that only reports CUDA/compute contexts, so on a
# desktop it returns literally nothing — Hyprland, the browser and games all
# hold GRAPHICS contexts. The plain-text Processes table is the only view that
# lists both (verified on driver 610.43.03).
# `pmon` also lists graphics pids but reports sm%/mem as "-" on this laptop,
# so it cannot supply the number either.
#
# Row shape:  |  0  N/A  N/A   20698   G   Hyprland   136MiB |
# The process name can contain spaces and slashes, so anchor on the ends:
# pid is $5 and the memory figure is $(NF-1) (last field is the closing bar).
gpu_pid_mem=""
if [[ ${gpu_present:-false} == true ]]; then
    gpu_pid_mem=$(nvidia-smi 2> /dev/null | awk '
        /Processes:/      { inproc = 1; next }
        !inproc           { next }
        /^\|[[:space:]]+[0-9]+[[:space:]]/ {
            mem = $(NF - 1)
            gsub(/[^0-9]/, "", mem)
            if ($5 ~ /^[0-9]+$/ && mem != "") print $5 "," mem
        }')
fi

# cmdline for every pid in one shot; per-pid reads would be 400 more syscalls
# and the panel only ever shows the selected rows anyway.
all_args=$(ps -eo pid=,args= 2> /dev/null)

# Ship the UNION of top-40-by-CPU and top-40-by-RSS. A CPU-only list would make
# the client-side memory sort a lie, which was already true before this rewrite.
procs=$(
    printf '%s\n' "$proc_tsv" | awk -F'\t' \
        -v gpumem="$gpu_pid_mem" -v args="$all_args" '
    BEGIN {
        n = split(gpumem, gl, "\n")
        for (i = 1; i <= n; i++) {
            split(gl[i], g, ",")
            if (g[1] != "") gmem[g[1] + 0] = g[2] + 0
        }
        n = split(args, al, "\n")
        for (i = 1; i <= n; i++) {
            line = al[i]
            sub(/^[ \t]+/, "", line)
            sp = index(line, " ")
            if (sp > 0) cmd[substr(line, 1, sp - 1) + 0] = substr(line, sp + 1)
        }
    }
    function esc(s) {
        gsub(/\\/, "\\\\", s); gsub(/"/, "\\\"", s)
        gsub(/\t/, " ", s);    gsub(/[\r\n]/, "", s)
        return s
    }
    NF >= 9 {
        pid[NR] = $1; cpu[NR] = $2 + 0; mem[NR] = $3 + 0; st[NR] = $4
        pp[NR] = $5; th[NR] = $6; ni[NR] = $7; who[NR] = $8; nm[NR] = $9
        for (i = 10; i <= NF; i++) nm[NR] = nm[NR] " " $i
        rows++
    }
    END {
        for (i = 1; i <= rows; i++) { oc[i] = i; om[i] = i }
        # partial selection sort — only the top 40 of each ordering is needed
        for (k = 1; k <= 40 && k <= rows; k++) {
            b = k; for (i = k + 1; i <= rows; i++) if (cpu[oc[i]] > cpu[oc[b]]) b = i
            t = oc[k]; oc[k] = oc[b]; oc[b] = t
            b = k; for (i = k + 1; i <= rows; i++) if (mem[om[i]] > mem[om[b]]) b = i
            t = om[k]; om[k] = om[b]; om[b] = t
        }
        for (k = 1; k <= 40 && k <= rows; k++) { keep[oc[k]] = 1; keep[om[k]] = 1 }

        first = 1
        for (i = 1; i <= rows; i++) {
            if (!(i in keep)) continue
            c = (pid[i] + 0 in cmd) ? cmd[pid[i] + 0] : nm[i]
            if (length(c) > 160) c = substr(c, 1, 159) "…"
            printf "%s{\"pid\":%d,\"name\":\"%s\",\"cpu\":%.2f,\"mem\":%.1f,\"gpuMem\":%d,\"state\":\"%s\",\"ppid\":%d,\"threads\":%d,\"nice\":%d,\"user\":\"%s\",\"cmd\":\"%s\"}", \
                   (first ? "" : ","), pid[i], esc(nm[i]), cpu[i], mem[i], \
                   (pid[i] + 0 in gmem ? gmem[pid[i] + 0] : 0), st[i], pp[i], th[i], ni[i], esc(who[i]), esc(c)
            first = 0
        }
    }'
)

# --- network -----------------------------------------------------------------
iface=$(ip route show default 2> /dev/null | awk '/^default/{print $5;exit}')
ipaddr=$(ip route get 1.1.1.1 2> /dev/null | awk '{for(i=1;i<=NF;i++) if($i=="src"){print $(i+1);exit}}')
conn=$(nmcli -t -f NAME,DEVICE connection show --active 2> /dev/null | awk -F: -v d="$iface" '$2==d{print $1;exit}')
ctype="ethernet"
[[ -d /sys/class/net/${iface:-none}/wireless ]] && ctype="wifi"
signal=0
if [[ $ctype == wifi ]]; then
    signal=$(nmcli -t -f active,signal dev wifi 2> /dev/null | awk -F: '$1=="yes"{print $2;exit}')
    [[ -z $signal ]] && signal=0
fi

rx=0 tx=0
if [[ -n ${iface:-} && -d /sys/class/net/$iface ]]; then
    rx=$(< "/sys/class/net/$iface/statistics/rx_bytes")
    tx=$(< "/sys/class/net/$iface/statistics/tx_bytes")
fi

cat << JSON
{
  "cpu": $cpu,
  "cores": $cores,
  "ncpu": $NCPU,
  "cpuTemp": $cputemp,
  "memPct": $mem_pct,
  "memUsed": $mem_used,
  "memTotal": $mem_total,
  "swapPct": $swap_pct,
  "swapUsed": $swap_used,
  "swapTotal": $swap_total,
  "gpuPresent": $gpu_present,
  "gpuName": "$gpu_name",
  "gpu": ${gpu:-0},
  "gpuTemp": ${gpu_temp:-0},
  "gpuPower": ${gpu_power:-0},
  "vramUsed": ${vram_used:-0},
  "vramTotal": ${vram_total:-0},
  "me": "${USER:-$(id -un)}",
  "power": {
    "profile": "${pprofile:-}",
    "fanCpu": ${fan_cpu:-0},
    "fanGpu": ${fan_gpu:-0},
    "pl1": ${ppt_pl1:-0},
    "pl2": ${ppt_pl2:-0},
    "nvBoost": ${nv_boost:-0},
    "nvTemp": ${nv_temp:-0},
    "muxMode": ${mux_mode:-0},
    "dgpuOff": ${dgpu_off:-0},
    "rebootPending": ${reboot_pending:-0},
    "kbdLed": ${kbd_led:-0},
    "kbdLedMax": ${kbd_led_max:-3}
  },
  "bat": {
    "present": ${bat_present:-false},
    "pct": ${bat_pct:-0},
    "status": "${bat_status:-}",
    "energy": ${bat_energy:-0},
    "full": ${bat_full:-0},
    "design": ${bat_design:-0},
    "draw": ${bat_draw:-0},
    "limit": ${bat_limit:-0},
    "cycles": ${bat_cycles:-0},
    "ac": ${ac_online:-0}
  },
  "load": "$l1 $l5 $l15",
  "uptime": "$up_str",
  "procs": [$procs],
  "net": {
    "iface": "${iface:-}",
    "ip": "${ipaddr:-}",
    "conn": "${conn:-}",
    "type": "$ctype",
    "signal": ${signal:-0},
    "rx": $rx,
    "tx": $tx
  }
}
JSON
