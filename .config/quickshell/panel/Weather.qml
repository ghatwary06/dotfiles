pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// ===========================================================================
//  Weather, read from the cache that waybar's weather.sh maintains.
//  Deliberately no fetching here: one script owns the network call, both
//  surfaces read the same file, so the bar and the dashboard can never show
//  different numbers — and wttr.in gets hit once every 15 minutes, not twice.
// ===========================================================================
Singleton {
    id: root

    property bool ok: false
    property string icon: ""
    property string temp: "--"
    property string feels: "--"
    property string desc: ""
    property string area: ""
    property string country: ""
    property string humidity: "--"
    property string wind: "--"
    property string windDir: ""
    property string uv: "--"
    property string precip: "0"
    property string pressure: "--"
    property string visibility: "--"
    property string tmin: "--"
    property string tmax: "--"
    property string sunrise: "--"
    property string sunset: "--"
    property var forecast: []
    property var hourly: []

    // Nudge the script to refresh; it no-ops if the cache is still fresh.
    function refresh() {
        poke.running = true;
    }

    Process {
        id: poke
        command: ["sh", "-c", "$HOME/.config/waybar/scripts/weather.sh >/dev/null 2>&1"]
        running: false
    }

    FileView {
        id: file
        path: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/rice/weather.json"
        watchChanges: true
        printErrors: false

        onFileChanged: reload()
        onLoaded: root._parse(this.text())
    }

    function _parse(raw) {
        if (!raw || raw.length === 0)
            return;
        let d;
        try {
            d = JSON.parse(raw);
        } catch (e) {
            return;
        }
        if (!d.ok) {
            ok = false;
            return;
        }

        ok = true;
        icon = d.icon || "";
        temp = d.temp;
        feels = d.feels;
        desc = d.desc || "";
        area = d.area || "";
        country = d.country || "";
        humidity = d.humidity;
        wind = d.wind;
        windDir = d.windDir || "";
        uv = d.uv;
        precip = d.precip;
        pressure = d.pressure;
        visibility = d.visibility;
        tmin = d.min;
        tmax = d.max;
        sunrise = d.sunrise || "--";
        sunset = d.sunset || "--";
        forecast = d.forecast || [];
        hourly = d.hourly || [];
    }

    // UV index is the one number people misread — label it.
    function uvLabel() {
        const v = parseInt(uv);
        if (isNaN(v))
            return "";
        if (v <= 2)
            return "low";
        if (v <= 5)
            return "moderate";
        if (v <= 7)
            return "high";
        if (v <= 10)
            return "very high";
        return "extreme";
    }

    function dayName(iso) {
        const d = new Date(iso + "T12:00:00");
        return ["sun", "mon", "tue", "wed", "thu", "fri", "sat"][d.getDay()];
    }
}
