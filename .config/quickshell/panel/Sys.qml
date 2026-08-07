pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// ===========================================================================
//  System telemetry. One `sysinfo.sh` fork per tick, parsed as JSON.
//  Polling only runs while something is actually looking (`subscribers > 0`)
//  so a closed panel costs nothing — waybar has its own lighter glance module.
// ===========================================================================
Singleton {
    id: root

    property int subscribers: 0
    readonly property bool active: subscribers > 0

    // -- live values --------------------------------------------------------
    property int cpu: 0
    property var cores: []
    property int cpuTemp: 0

    property int memPct: 0
    property int memUsed: 0      // KiB
    property int memTotal: 0     // KiB
    property int swapPct: 0
    property int swapUsed: 0
    property int swapTotal: 0

    property bool gpuPresent: false
    property string gpuName: ""
    property int gpu: 0
    property int gpuTemp: 0
    property real gpuPower: 0
    property int vramUsed: 0     // MiB
    property int vramTotal: 0

    property string load: "—"
    property string uptime: "—"
    property var procs: []
    property int ncpu: 1
    property string me: ""   // current user, for the "my processes" filter

    property string netIface: ""
    property string netIp: ""
    property string netConn: ""
    property string netType: ""
    property int netSignal: 0
    property real rxRate: 0      // bytes/s
    property real txRate: 0

    property string publicIp: ""
    property bool publicIpLoading: false

    // Previous counters, for turning monotonic byte totals into a rate.
    property real _rx: 0
    property real _tx: 0
    property real _stamp: 0

    // -- helpers ------------------------------------------------------------
    function gib(kib) {
        return (kib / 1048576).toFixed(1);
    }

    function rate(bps) {
        if (bps < 1024)
            return Math.round(bps) + " B/s";
        if (bps < 1048576)
            return Math.round(bps / 1024) + " KB/s";
        return (bps / 1048576).toFixed(1) + " MB/s";
    }

    function subscribe() {
        subscribers++;
        if (subscribers === 1) {
            poll.running = true;
            probe.running = true;   // prime immediately, don't wait a full tick
        }
    }

    function unsubscribe() {
        subscribers = Math.max(0, subscribers - 1);
        if (subscribers === 0)
            poll.running = false;
    }

    // -- ingest -------------------------------------------------------------
    function _ingest(raw) {
        if (!raw || raw.length === 0)
            return;

        let d;
        try {
            d = JSON.parse(raw);
        } catch (e) {
            console.warn("Sys: unparseable sysinfo output:", e);
            return;
        }

        cpu = d.cpu;
        cores = d.cores || [];
        cpuTemp = d.cpuTemp;

        memPct = d.memPct;
        memUsed = d.memUsed;
        memTotal = d.memTotal;
        swapPct = d.swapPct;
        swapUsed = d.swapUsed;
        swapTotal = d.swapTotal;

        gpuPresent = d.gpuPresent;
        gpuName = d.gpuName || "";
        gpu = d.gpu;
        gpuTemp = d.gpuTemp;
        gpuPower = d.gpuPower;
        vramUsed = d.vramUsed;
        vramTotal = d.vramTotal;

        load = d.load;
        uptime = d.uptime;
        procs = d.procs || [];
        ncpu = d.ncpu || ncpu;
        me = d.me || me;
        power = d.power || ({});
        bat = d.bat || ({});

        cpuHist = _push(cpuHist, d.cpu || 0);
        gpuHist = _push(gpuHist, d.gpuPresent ? (d.gpu || 0) : 0);
        memHist = _push(memHist, d.memPct || 0);

        const n = d.net || {};
        netIface = n.iface || "";
        netIp = n.ip || "";
        netConn = n.conn || "";
        netType = n.type || "";
        netSignal = n.signal || 0;

        const now = Date.now();
        if (_stamp > 0 && n.rx >= _rx && n.tx >= _tx) {
            const dt = (now - _stamp) / 1000;
            if (dt > 0.1) {
                rxRate = (n.rx - _rx) / dt;
                txRate = (n.tx - _tx) / dt;
            }
        }
        _rx = n.rx || 0;
        _tx = n.tx || 0;
        _stamp = now;
    }

    // Public IP is fetched only on explicit request — the panel should not be
    // phoning a third party every time it opens.
    function fetchPublicIp() {
        publicIpLoading = true;
        pubip.running = true;
    }

    // -- power / battery / firmware -----------------------------------------
    property var power: ({})
    property var bat: ({})

    signal powerActed(string what, bool ok)

    // All writes funnel through powerctl.sh — see the header there for why
    // gpu_mux_mode, dgpu_disable and the charge limit are deliberately absent.
    function setProfile(p) {
        pw.what = p;
        pw.command = [ctlPath, "profile", p];
        pw.running = true;
    }

    function setArmoury(attr, val) {
        pw.what = attr;
        pw.command = [ctlPath, "armoury", attr, String(val)];
        pw.running = true;
    }

    function cycleKbd() {
        pw.what = "keyboard light";
        pw.command = [ctlPath, "kbd", "next"];
        pw.running = true;
    }

    readonly property string ctlPath: Quickshell.env("HOME") + "/.config/quickshell/panel/powerctl.sh"

    Process {
        id: pw
        property string what: ""
        running: false
        onExited: function (code) {
            root.powerActed(pw.what, code === 0);
            // Re-probe immediately so the card reflects the new value instead of
            // showing the stale one until the next 2s tick.
            if (root.active)
                probe.running = true;
        }
    }

    // -- process table state ------------------------------------------------
    // Lives here rather than in SecProcs so the IPC handler and the table are
    // driving the same state instead of two copies that can disagree.
    property string procSort: "cpu"     // cpu | mem | gpuMem | name | pid | user
    property bool procSortDesc: true
    property string procFilter: ""      // live substring match on name/cmd/user/pid
    property bool procGroup: false      // aggregate instances sharing a name
    property bool procUserOnly: false   // hide other users' (mostly root/system) rows

    readonly property var procSortKeys: ["cpu", "mem", "gpuMem", "name", "pid", "user"]

    function setProcSort(key) {
        if (procSortKeys.indexOf(key) < 0)
            return false;
        if (procSort === key) {
            procSortDesc = !procSortDesc;
        } else {
            procSort = key;
            // Usage columns start high-to-low; name/pid/user read better ascending.
            procSortDesc = (key === "cpu" || key === "mem" || key === "gpuMem");
        }
        return true;
    }

    // -- CPU / GPU / MEM history, for the sparklines ------------------------
    // Fixed-length ring kept in the model rather than the view, so switching
    // panel tabs does not reset the graph.
    readonly property int histLen: 60
    property var cpuHist: []
    property var gpuHist: []
    property var memHist: []

    function _push(arr, v) {
        const a = arr.slice();
        a.push(v);
        while (a.length > histLen)
            a.shift();
        return a;
    }

    // -- process actions ----------------------------------------------------
    signal processActed(int pid, string action, bool ok)

    // Everything routes through one signal sender so there is a single place
    // where a pid is validated. Signalling pid 1 or a bogus row is refused
    // outright rather than handed to kill(1).
    function signalPid(pid, sig, label) {
        if (!pid || pid <= 1)
            return false;
        killer.pid = pid;
        killer.action = label;
        killer.command = ["kill", "-" + sig, String(pid)];
        killer.running = true;
        return true;
    }

    // SIGTERM lets the app save and exit cleanly; SIGKILL is the escalation
    // when it ignores that. The panel asks which one — it never guesses.
    function killPid(pid, force) {
        return signalPid(pid, force ? "KILL" : "TERM", force ? "force" : "terminate");
    }

    function stopPid(pid) {
        return signalPid(pid, "STOP", "stopped");
    }

    function contPid(pid) {
        return signalPid(pid, "CONT", "resumed");
    }

    // renice can only ever LOWER priority without privileges; raising it back
    // needs root, so a failure here is expected and reported, not swallowed.
    function renicePid(pid, delta) {
        if (!pid || pid <= 1)
            return false;
        killer.pid = pid;
        killer.action = "reniced";
        killer.command = ["sh", "-c", "renice -n " + delta + " -p " + pid + " >/dev/null 2>&1"];
        killer.running = true;
        return true;
    }

    // Kill every process sharing a name — the "this app spawned 30 helpers"
    // case that makes a per-row kill useless.
    function killGroup(name, force) {
        const pids = (procs || []).filter(p => p.name === name && p.pid > 1).map(p => p.pid);
        if (pids.length === 0)
            return false;
        killer.pid = pids[0];
        killer.action = (force ? "killed " : "terminated ") + pids.length + "× " + name;
        killer.command = ["kill", force ? "-KILL" : "-TERM"].concat(pids.map(String));
        killer.running = true;
        return true;
    }

    function copyPid(pid) {
        copyText(String(pid));
    }

    // Text goes to wl-copy on stdin, never interpolated into a shell string —
    // a cmdline legitimately contains quotes, $ and backticks.
    function copyText(t) {
        clip.command = ["wl-copy", "--", String(t)];
        clip.running = true;
    }

    Process {
        id: killer
        property int pid: 0
        property string action: ""
        running: false
        onExited: function (code) {
            root.processActed(killer.pid, killer.action, code === 0);
            // Refresh straight away so the row disappears immediately rather
            // than lingering until the next 2s poll.
            if (root.active)
                probe.running = true;
        }
    }

    Process {
        id: clip
        running: false
    }

    Process {
        id: probe
        command: ["sh", "-c", "$HOME/.config/quickshell/panel/sysinfo.sh"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: root._ingest(this.text)
        }
    }

    Process {
        id: pubip
        command: ["sh", "-c", "curl -s --max-time 4 https://ifconfig.me/ip || echo unavailable"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                root.publicIp = this.text.trim();
                root.publicIpLoading = false;
            }
        }
    }

    Timer {
        id: poll
        interval: 2000
        repeat: true
        running: false
        onTriggered: {
            if (!probe.running)
                probe.running = true;
        }
    }
}
