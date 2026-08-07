pragma Singleton

import Quickshell
import Quickshell.Services.Pipewire
import QtQuick

// ===========================================================================
//  Audio outputs. Lets the dashboard switch where sound goes without opening
//  pavucontrol — pick the headset or the monitor while the track is playing.
// ===========================================================================
Singleton {
    id: root

    // Real output devices only. `isStream` filters out per-application nodes
    // (Spotify, Firefox…), which are also "sinks" as far as PipeWire cares but
    // are not somewhere you can send audio.
    readonly property var sinks: {
        const all = Pipewire.nodes ? Pipewire.nodes.values : [];
        return all.filter(n => n && n.isSink && !n.isStream);
    }

    readonly property PwNode current: Pipewire.defaultAudioSink

    // Quickshell only binds a node's properties (description, volume, muted)
    // while something TRACKS it. Without this the labels come back empty.
    PwObjectTracker {
        objects: root.sinks
    }

    // `preferredDefaultAudioSink` is the writable half of the default-sink pair;
    // `defaultAudioSink` itself is read-only and reflects what PipeWire settled
    // on. Writing the preference is what `wpctl set-default` does.
    function setSink(node) {
        if (!node)
            return false;
        Pipewire.preferredDefaultAudioSink = node;
        return true;
    }

    // Friendly-ish name. PipeWire descriptions are long and hardware-flavoured
    // ("AD107 High Definition Audio Controller Digital Stereo (HDMI)"), so trim
    // the noise down to something readable in a 400px panel.
    function label(n) {
        if (!n)
            return "—";
        let s = n.description || n.nickname || n.name || "output";
        s = s.replace(/ Analog Stereo$/, "").replace(/ Digital Stereo/, "").replace(/High Definition Audio Controller/, "").replace(/\s+/g, " ").trim();
        return s.length > 34 ? s.slice(0, 33) + "…" : s;
    }

    // Rough device class, for the icon.
    function icon(n) {
        const s = ((n && (n.description || n.name)) || "").toLowerCase();
        if (s.indexOf("hdmi") >= 0 || s.indexOf("displayport") >= 0)
            return "󰍹";      // monitor
        if (s.indexOf("wireless") >= 0 || s.indexOf("headset") >= 0 || s.indexOf("headphone") >= 0 || s.indexOf("bluez") >= 0)
            return "󰋋";      // headset
        if (s.indexOf("easy effects") >= 0 || s.indexOf("easyeffects") >= 0)
            return "󰋼";      // virtual / processing sink
        return "󰓃";          // speakers
    }
}
