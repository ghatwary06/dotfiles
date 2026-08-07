pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// ===========================================================================
//  Brightness for both displays.
//
//  The two paths are NOT interchangeable — measured on this machine:
//    laptop   brightnessctl / sysfs backlight   ~2ms      write freely
//    external ddcutil DDC/CI over i2c          ~500-1300ms  MUST be debounced
//
//  So the laptop slider writes on every change, and the external one updates
//  its displayed value instantly but only sends the real write once the drag
//  settles. Without that, dragging queues a second of lag per pixel moved.
// ===========================================================================
Singleton {
    id: root

    property int laptop: 50
    property int external: 100
    property bool hasExternal: false

    // True while a DDC write is actually on the wire.
    property bool externalBusy: false
    // Set when the value changed again mid-write; the write is re-run on exit
    // so the monitor always ends up at the value the slider is showing.
    property bool externalPending: false

    readonly property string ctl: Quickshell.env("HOME") + "/.config/quickshell/panel/brightness.sh"

    function refresh() {
        if (!getProc.running)
            getProc.running = true;
    }

    function setLaptop(v) {
        const n = Math.max(1, Math.min(100, Math.round(v)));
        if (n === laptop)
            return;
        laptop = n;
        // Cheap enough to fire per change; no debounce needed.
        lapProc.command = [ctl, "set", "laptop", String(n)];
        lapProc.running = true;
    }

    function setExternal(v) {
        const n = Math.max(0, Math.min(100, Math.round(v)));
        if (n === external)
            return;
        external = n;              // optimistic: the UI must not wait a second
        debounce.restart();
    }

    // Fires once the slider has been still for a moment. Anything shorter and
    // a single drag produces a dozen ~1s writes that pile up behind each other.
    Timer {
        id: debounce
        interval: 220
        onTriggered: root._pushExternal()
    }

    function _pushExternal() {
        if (externalBusy) {
            externalPending = true;   // re-run when the current write finishes
            return;
        }
        externalBusy = true;
        extProc.command = [ctl, "set", "external", String(external)];
        extProc.running = true;
    }

    Process {
        id: getProc
        running: false
        command: [root.ctl, "get"]
        stdout: StdioCollector {
            onStreamFinished: {
                // "laptop=5 external=100"  (external is "-" when DDC fails)
                const t = String(this.text).trim();
                const l = t.match(/laptop=(\d+)/);
                const e = t.match(/external=(\d+)/);
                if (l)
                    root.laptop = parseInt(l[1]);
                if (e) {
                    root.external = parseInt(e[1]);
                    root.hasExternal = true;
                } else {
                    root.hasExternal = false;
                }
            }
        }
    }

    Process {
        id: lapProc
        running: false
    }

    Process {
        id: extProc
        running: false
        onExited: {
            root.externalBusy = false;
            if (root.externalPending) {
                root.externalPending = false;
                root._pushExternal();
            }
        }
    }
}
