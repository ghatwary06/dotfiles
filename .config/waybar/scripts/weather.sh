#!/usr/bin/env bash
# Weather for the bar, and the shared cache the dashboard reads.
#
# Fetches wttr.in at most once every REFRESH seconds and normalises the reply
# into $STATE_DIR/weather.json, which both this module and the Quickshell
# dashboard consume — so the two never disagree and we only hit the network once.
#
# Glyphs are \U escapes on purpose: astral-plane codepoints do not survive every
# editor/tool round-trip, and a silently blank icon is hard to spot.
set -uo pipefail

STATE_DIR="${XDG_RUNTIME_DIR:-/tmp}/rice"
CACHE="$STATE_DIR/weather.json"
RAW="$STATE_DIR/weather-raw.json"
LOCK="$STATE_DIR/weather.lock"
REFRESH=900     # 15 minutes
ACCENT="#5E81AC" # keep in sync with waybar/colors.css @acc

mkdir -p "$STATE_DIR"

g() { printf "\\U000$1"; }

# WWO weather code -> glyph. Night variants are picked for the clear/partly
# cases only; the rest look the same whatever the hour.
icon_for() { # icon_for <code> <is_night>
    local c=$1 night=$2
    case "$c" in
        113) [[ $night == 1 ]] && g F0594 || g F0599 ;;                 # clear
        116) [[ $night == 1 ]] && g F0F31 || g F0595 ;;                 # partly cloudy
        119 | 122) g F0590 ;;                                           # cloudy / overcast
        143 | 248 | 260) g F0591 ;;                                     # mist / fog
        176 | 263 | 266 | 281 | 284 | 293 | 296 | 299 | 353) g F0597 ;; # drizzle / light rain
        302 | 305 | 308 | 356 | 359) g F0596 ;;                         # heavy rain
        179 | 227 | 230 | 323 | 326 | 329 | 332 | 335 | 338 | 368 | 371) g F0598 ;;
        182 | 185 | 311 | 314 | 317 | 320 | 350 | 362 | 365 | 374 | 377) g F0592 ;;
        200 | 386 | 389 | 392 | 395) g F0593 ;;                         # thunder
        *) g F0590 ;;
    esac
}

# --- refresh if stale --------------------------------------------------------
stale=1
if [[ -s $RAW ]]; then
    age=$(($(date +%s) - $(stat -c %Y "$RAW")))
    ((age < REFRESH)) && stale=0
fi

if ((stale)); then
    # flock keeps two waybar ticks from racing into a double fetch.
    (
        flock -n 9 || exit 0
        tmp=$(mktemp "$STATE_DIR/wx.XXXXXX")
        if curl -sf --max-time 12 "https://wttr.in/?format=j1" -o "$tmp" \
            && jq -e '.current_condition[0]' "$tmp" > /dev/null 2>&1; then
            mv "$tmp" "$RAW"
        else
            rm -f "$tmp"
            # Touch the old file so a hard-down network doesn't retry every tick.
            [[ -s $RAW ]] && touch "$RAW"
        fi
    ) 9> "$LOCK"
fi

if [[ ! -s $RAW ]]; then
    printf '{"text":"%s --°","tooltip":"weather unavailable","class":"offline"}\n' "$(g F0590)"
    printf '{"ok":false}\n' > "$CACHE"
    exit 0
fi

# --- normalise ---------------------------------------------------------------
hour=$(date +%-H)
night=0
((hour < 6 || hour >= 18)) && night=1

# IFS is pinned to tab: several of these values legitimately contain spaces
# ("Qism El Gumruk", "Partly cloudy", "05:19 AM"), and the default IFS would
# split them across variables.
IFS=$'\t' read -r code temp feels desc hum wind winddir uv precip vis pressure area country < <(
    jq -r '.current_condition[0] as $c | .nearest_area[0] as $a |
        [$c.weatherCode, $c.temp_C, $c.FeelsLikeC, $c.weatherDesc[0].value,
         $c.humidity, $c.windspeedKmph, $c.winddir16Point, $c.uvIndex,
         $c.precipMM, $c.visibility, $c.pressure,
         $a.areaName[0].value, $a.country[0].value]
        | @tsv' "$RAW"
)

icon=$(icon_for "$code" "$night")

# Today's range + a short forecast for the dashboard.
IFS=$'\t' read -r tmin tmax sunrise sunset < <(
    jq -r '.weather[0] | [.mintempC, .maxtempC, .astronomy[0].sunrise, .astronomy[0].sunset] | @tsv' "$RAW"
)

forecast=$(jq -c '[.weather[0:3][] | {
        date: .date,
        min: .mintempC,
        max: .maxtempC,
        code: .hourly[4].weatherCode,
        desc: .hourly[4].weatherDesc[0].value
    }]' "$RAW")

hourly=$(jq -c '[.weather[0].hourly[] | {
        time: (.time | tonumber / 100 | floor),
        temp: .tempC,
        code: .weatherCode,
        rain: .chanceofrain
    }]' "$RAW")

# Shared cache for the Quickshell dashboard.
jq -n --arg icon "$icon" --arg temp "$temp" --arg feels "$feels" --arg desc "$desc" \
    --arg hum "$hum" --arg wind "$wind" --arg winddir "$winddir" --arg uv "$uv" \
    --arg precip "$precip" --arg vis "$vis" --arg pressure "$pressure" \
    --arg area "$area" --arg country "$country" --arg tmin "$tmin" --arg tmax "$tmax" \
    --arg sunrise "$sunrise" --arg sunset "$sunset" --arg code "$code" \
    --argjson forecast "$forecast" --argjson hourly "$hourly" \
    '{ok:true, icon:$icon, code:$code, temp:$temp, feels:$feels, desc:$desc,
      humidity:$hum, wind:$wind, windDir:$winddir, uv:$uv, precip:$precip,
      visibility:$vis, pressure:$pressure, area:$area, country:$country,
      min:$tmin, max:$tmax, sunrise:$sunrise, sunset:$sunset,
      forecast:$forecast, hourly:$hourly}' > "$CACHE"

class=mild
((temp <= 5)) && class=cold
((temp >= 32)) && class=hot

# The glyph is wrapped in an accent span so only the icon is tinted, not the
# temperature next to it. Waybar renders custom-module text as Pango markup.
printf '{"text":"<span color=\\"%s\\">%s</span> %s°","tooltip":"%s — %s°C (feels %s°C)\\r%s\\r%s%% humidity · %s km/h %s\\r\\rclick → dashboard","class":"%s"}\n' \
    "$ACCENT" "$icon" "$temp" "$area" "$temp" "$feels" "$desc" "$hum" "$wind" "$winddir" "$class"
