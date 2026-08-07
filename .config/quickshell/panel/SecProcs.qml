import QtQuick
import QtQuick.Layouts

// Process manager: live meters, filter, sort, grouping, per-process control.
//
// CPU% comes from sysinfo.sh's delta sampler (top-style, per-core normalised),
// NOT from `ps pcpu` — see the long comment there. A row reading 200% is a
// process using two cores, not a bug.
//
// Killing stays two-step. A single mis-click in an always-open status panel
// must never be able to SIGKILL a browser, so a row expands into an explicit
// action strip rather than acting on the first click.
WCard {
    id: card

    readonly property string sortKey: Sys.procSort
    readonly property bool sortDesc: Sys.procSortDesc
    property int expandedPid: 0         // row showing its detail/action strip
    property int confirmPid: 0          // row armed for a destructive action
    property string lastMsg: ""
    property bool lastErr: false

    title: "PROCESSES"
    hint: card.rows.length + " / " + (Sys.procs || []).length

    function setSort(key) {
        Sys.setProcSort(key);
        confirmPid = 0;
    }

    function say(msg, err) {
        lastMsg = msg;
        lastErr = err === true;
        msgTimer.restart();
    }

    // ---------------------------------------------------------------- data -- //
    // filter -> optional grouping -> sort. Grouping happens BEFORE sorting so
    // that sorting a grouped view orders the aggregates, not the members.
    readonly property var rows: {
        let list = (Sys.procs || []).slice();

        const q = Sys.procFilter.trim().toLowerCase();
        if (q.length > 0) {
            list = list.filter(function (p) {
                return String(p.name).toLowerCase().indexOf(q) >= 0 || String(p.cmd).toLowerCase().indexOf(q) >= 0 || String(p.user).toLowerCase().indexOf(q) >= 0 || String(p.pid).indexOf(q) >= 0;
            });
        }

        if (Sys.procUserOnly)
            list = list.filter(p => p.user === Sys.me);

        if (Sys.procGroup) {
            const by = {};
            for (const p of list) {
                const g = by[p.name];
                if (!g) {
                    by[p.name] = {
                        name: p.name,
                        pid: p.pid,
                        cpu: p.cpu,
                        mem: p.mem,
                        gpuMem: p.gpuMem,
                        user: p.user,
                        state: p.state,
                        ppid: p.ppid,
                        threads: p.threads,
                        nice: p.nice,
                        cmd: p.cmd,
                        count: 1,
                        _topCpu: p.cpu
                    };
                } else {
                    g.cpu += p.cpu;
                    g.mem += p.mem;
                    g.gpuMem += p.gpuMem;
                    g.threads += p.threads;
                    g.count++;
                    // Represent the group by its heaviest MEMBER, so acting on
                    // the row without expanding hits the one that matters.
                    // Compare against the running max, not the running SUM —
                    // comparing to the sum makes the winner depend on iteration
                    // order and picks the wrong pid as soon as a group has 3+.
                    if (p.cpu > g._topCpu) {
                        g._topCpu = p.cpu;
                        g.pid = p.pid;
                        g.cmd = p.cmd;
                        g.state = p.state;
                        g.nice = p.nice;
                        g.ppid = p.ppid;
                    }
                }
            }
            list = Object.keys(by).map(k => by[k]);
        } else {
            list = list.map(function (p) {
                const c = Object.assign({}, p);
                c.count = 1;
                return c;
            });
        }

        const k = card.sortKey;
        const dir = card.sortDesc ? -1 : 1;
        list.sort(function (a, b) {
            let av = a[k], bv = b[k];
            if (k === "name" || k === "user") {
                av = String(av).toLowerCase();
                bv = String(bv).toLowerCase();
                if (av === bv)
                    return a.pid - b.pid;
                return av < bv ? -dir : dir;
            }
            if (av === bv)
                return a.pid - b.pid;   // stable tiebreak, stops row jitter
            return av < bv ? -dir : dir;
        });
        return list.slice(0, 20);
    }

    Connections {
        target: Sys
        function onProcessActed(pid, action, ok) {
            card.say(ok ? action + " " + pid : action + " failed on " + pid + " (permission?)", !ok);
            if (ok)
                card.confirmPid = 0;
        }
    }

    Timer {
        id: msgTimer
        interval: 3500
        onTriggered: card.lastMsg = ""
    }

    // NOTE: a CPU/GPU/MEM meter strip used to sit here. Removed 2026-08-06 — it
    // repeated the PROCESSOR / MEMORY / GPU cards immediately above it, so the
    // same three numbers appeared twice on one screen. SecPower took the slot.
    // Sys.cpuHist/gpuHist/memHist and Spark.qml are still live; the sparklines
    // moved nowhere else yet, so those are available if a graph is wanted back.

    // ------------------------------------------------------------- toolbar -- //
    RowLayout {
        Layout.fillWidth: true
        spacing: 6

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 22
            radius: Theme.radiusSm
            color: Theme.a(Theme.bg2, search.activeFocus ? 0.8 : 0.45)
            border.width: 1
            border.color: search.activeFocus ? Theme.a(Theme.acc, 0.55) : Theme.bdr

            Text {
                anchors.left: parent.left
                anchors.leftMargin: 6
                anchors.verticalCenter: parent.verticalCenter
                text: "󰍉"
                color: search.activeFocus ? Theme.acc : Theme.fgFaint
                font.family: Theme.font
                font.pixelSize: Theme.fsSm
            }

            TextInput {
                id: search
                anchors.fill: parent
                anchors.leftMargin: 22
                anchors.rightMargin: 20
                verticalAlignment: Text.AlignVCenter
                color: Theme.fg
                font.family: Theme.font
                font.pixelSize: Theme.fsSm
                selectByMouse: true
                selectionColor: Theme.a(Theme.acc, 0.35)
                clip: true
                text: Sys.procFilter
                onTextChanged: Sys.procFilter = text
                // Escape clears the filter first and only closes the panel when
                // it is already empty, so a stray Esc mid-search is not fatal.
                Keys.onEscapePressed: function (e) {
                    if (text.length > 0) {
                        text = "";
                        e.accepted = true;
                    } else {
                        e.accepted = false;
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "filter by name, cmd, user or pid"
                    color: Theme.fgFaint
                    font.family: Theme.font
                    font.pixelSize: Theme.fsSm
                    visible: search.text.length === 0 && !search.activeFocus
                }
            }

            Text {
                anchors.right: parent.right
                anchors.rightMargin: 6
                anchors.verticalCenter: parent.verticalCenter
                text: "󰅖"
                color: clrMa.containsMouse ? Theme.crit : Theme.fgFaint
                font.family: Theme.font
                font.pixelSize: Theme.fsXs
                visible: search.text.length > 0

                MouseArea {
                    id: clrMa
                    anchors.fill: parent
                    anchors.margins: -4
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: search.text = ""
                }
            }
        }

        Repeater {
            model: [
                {
                    k: "group",
                    icon: "󰡍",
                    tip: "group by name"
                },
                {
                    k: "user",
                    icon: "󰀄",
                    tip: "my processes only"
                }
            ]

            Rectangle {
                id: tog
                required property var modelData
                readonly property bool on: modelData.k === "group" ? Sys.procGroup : Sys.procUserOnly

                implicitWidth: 24
                implicitHeight: 22
                radius: Theme.radiusSm
                color: on ? Theme.a(Theme.acc, 0.18) : (tma.containsMouse ? Theme.a(Theme.chipHi, 0.8) : Theme.a(Theme.bg2, 0.45))
                border.width: 1
                border.color: on ? Theme.a(Theme.acc, 0.55) : Theme.bdr

                Text {
                    anchors.centerIn: parent
                    text: tog.modelData.icon
                    color: tog.on ? Theme.acc : Theme.fgDim
                    font.family: Theme.font
                    font.pixelSize: Theme.fsSm
                }

                MouseArea {
                    id: tma
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (tog.modelData.k === "group")
                            Sys.procGroup = !Sys.procGroup;
                        else
                            Sys.procUserOnly = !Sys.procUserOnly;
                        card.expandedPid = 0;
                        card.confirmPid = 0;
                    }
                }
            }
        }
    }

    // -------------------------------------------------------- column header -- //
    RowLayout {
        Layout.fillWidth: true
        spacing: Theme.gap

        Repeater {
            model: [
                {
                    key: "name",
                    label: "process",
                    w: 0,
                    grow: true
                },
                {
                    key: "user",
                    label: "user",
                    w: 46,
                    grow: false
                },
                {
                    key: "gpuMem",
                    label: "gpu",
                    w: 44,
                    grow: false
                },
                {
                    key: "mem",
                    label: "mem",
                    w: 50,
                    grow: false
                },
                {
                    key: "cpu",
                    label: "cpu",
                    w: 48,
                    grow: false
                }
            ]

            Item {
                id: hcell
                required property var modelData
                readonly property bool activeSort: card.sortKey === modelData.key

                Layout.fillWidth: modelData.grow
                Layout.minimumWidth: modelData.grow ? 60 : modelData.w
                Layout.preferredWidth: modelData.grow ? 1 : modelData.w
                implicitHeight: 14

                Text {
                    anchors.left: hcell.modelData.grow ? parent.left : undefined
                    anchors.right: hcell.modelData.grow ? undefined : parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: hcell.modelData.label + (hcell.activeSort ? (card.sortDesc ? " ↓" : " ↑") : "")
                    color: hcell.activeSort ? Theme.acc : (hma.containsMouse ? Theme.fg : Theme.fgFaint)
                    font.family: Theme.font
                    font.pixelSize: Theme.fsXs
                    font.weight: hcell.activeSort ? Font.Bold : Font.Normal
                }

                MouseArea {
                    id: hma
                    anchors.fill: parent
                    anchors.margins: -3
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: card.setSort(hcell.modelData.key)
                }
            }
        }

        Item {
            Layout.preferredWidth: 14
        }
    }

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: 1
        color: Theme.bdr
    }

    // ---------------------------------------------------------------- rows -- //
    Repeater {
        model: card.rows

        ColumnLayout {
            id: rowWrap
            required property var modelData
            readonly property bool expanded: card.expandedPid === modelData.pid

            Layout.fillWidth: true
            spacing: 0

            Rectangle {
                id: row
                Layout.fillWidth: true
                implicitHeight: 22
                radius: Theme.radiusSm
                color: rowWrap.expanded ? Theme.a(Theme.acc, 0.10) : (rma.containsMouse ? Theme.a(Theme.chipHi, 0.8) : "transparent")
                border.width: 1
                border.color: rowWrap.expanded ? Theme.a(Theme.acc, 0.35) : "transparent"

                Behavior on color {
                    ColorAnimation {
                        duration: Theme.animFast
                    }
                }

                // CPU load bar behind the row — the table reads as a graph at a
                // glance instead of a wall of numbers. Scaled to ONE core, so a
                // multi-core hog simply pins the bar.
                Rectangle {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    anchors.margins: 1
                    width: Math.max(0, Math.min(1, rowWrap.modelData.cpu / 100)) * (parent.width - 2)
                    radius: Theme.radiusSm
                    color: Theme.a(rowWrap.modelData.cpu >= 100 ? Theme.crit : rowWrap.modelData.cpu >= 40 ? Theme.warn : Theme.acc, 0.13)
                }

                MouseArea {
                    id: rma
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    cursorShape: Qt.PointingHandCursor
                    onClicked: function (m) {
                        if (m.button === Qt.RightButton) {
                            Sys.copyPid(rowWrap.modelData.pid);
                            card.say("copied pid " + rowWrap.modelData.pid);
                            return;
                        }
                        card.expandedPid = rowWrap.expanded ? 0 : rowWrap.modelData.pid;
                        card.confirmPid = 0;
                    }
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 4
                    anchors.rightMargin: 4
                    spacing: Theme.gap

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.minimumWidth: 60
                        Layout.preferredWidth: 1
                        spacing: 4

                        Text {
                            text: rowWrap.modelData.name
                            color: rowWrap.modelData.state === "Z" ? Theme.crit : rowWrap.modelData.state === "T" ? Theme.warn : Theme.fg
                            font.family: Theme.font
                            font.pixelSize: Theme.fsSm
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }

                        // instance count when grouped, "T"/"Z" state flag otherwise
                        Rectangle {
                            visible: rowWrap.modelData.count > 1 || rowWrap.modelData.state === "T" || rowWrap.modelData.state === "Z"
                            implicitWidth: cnt.implicitWidth + 8
                            implicitHeight: 13
                            radius: 3
                            color: Theme.a(rowWrap.modelData.state === "Z" ? Theme.crit : rowWrap.modelData.state === "T" ? Theme.warn : Theme.acc, 0.18)

                            Text {
                                id: cnt
                                anchors.centerIn: parent
                                text: rowWrap.modelData.count > 1 ? "×" + rowWrap.modelData.count : rowWrap.modelData.state
                                color: rowWrap.modelData.state === "Z" ? Theme.crit : rowWrap.modelData.state === "T" ? Theme.warn : Theme.acc
                                font.family: Theme.font
                                font.pixelSize: 9
                            }
                        }
                    }

                    Text {
                        text: rowWrap.modelData.user
                        color: rowWrap.modelData.user === Sys.me ? Theme.fgDim : Theme.fgFaint
                        font.family: Theme.font
                        font.pixelSize: Theme.fsXs
                        elide: Text.ElideRight
                        horizontalAlignment: Text.AlignRight
                        Layout.preferredWidth: 46
                    }

                    Text {
                        text: rowWrap.modelData.gpuMem > 0 ? (rowWrap.modelData.gpuMem >= 1024 ? (rowWrap.modelData.gpuMem / 1024).toFixed(1) + "G" : rowWrap.modelData.gpuMem + "M") : "·"
                        color: rowWrap.modelData.gpuMem > 0 ? Theme.acc : Theme.fgFaint
                        font.family: Theme.font
                        font.pixelSize: Theme.fsXs
                        horizontalAlignment: Text.AlignRight
                        Layout.preferredWidth: 44
                    }

                    Text {
                        text: rowWrap.modelData.mem >= 1024 ? (rowWrap.modelData.mem / 1024).toFixed(1) + "G" : rowWrap.modelData.mem.toFixed(0) + "M"
                        color: rowWrap.modelData.mem >= 1024 ? Theme.warn : Theme.fgDim
                        font.family: Theme.font
                        font.pixelSize: Theme.fsXs
                        horizontalAlignment: Text.AlignRight
                        Layout.preferredWidth: 50
                    }

                    Text {
                        text: rowWrap.modelData.cpu >= 10 ? rowWrap.modelData.cpu.toFixed(0) + "%" : rowWrap.modelData.cpu.toFixed(1) + "%"
                        color: rowWrap.modelData.cpu >= 100 ? Theme.crit : rowWrap.modelData.cpu >= 40 ? Theme.warn : rowWrap.modelData.cpu >= 1 ? Theme.acc : Theme.fgFaint
                        font.family: Theme.font
                        font.pixelSize: Theme.fsXs
                        font.weight: rowWrap.modelData.cpu >= 40 ? Font.Bold : Font.Normal
                        horizontalAlignment: Text.AlignRight
                        Layout.preferredWidth: 48
                    }

                    Text {
                        text: rowWrap.expanded ? "󰅀" : "󰅂"
                        color: rowWrap.expanded ? Theme.acc : Theme.fgFaint
                        font.family: Theme.font
                        font.pixelSize: Theme.fsXs
                        Layout.preferredWidth: 14
                        horizontalAlignment: Text.AlignRight
                    }
                }
            }

            // ------------------------------------------------------ detail -- //
            Rectangle {
                Layout.fillWidth: true
                Layout.topMargin: rowWrap.expanded ? 2 : 0
                Layout.bottomMargin: rowWrap.expanded ? 4 : 0
                visible: rowWrap.expanded
                implicitHeight: rowWrap.expanded ? det.implicitHeight + 12 : 0
                radius: Theme.radiusSm
                color: Theme.a(Theme.bg2, 0.55)
                border.width: 1
                border.color: Theme.bdr

                ColumnLayout {
                    id: det
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 6
                    spacing: 5

                    Text {
                        Layout.fillWidth: true
                        text: rowWrap.modelData.cmd
                        color: Theme.fgDim
                        font.family: Theme.font
                        font.pixelSize: Theme.fsXs
                        wrapMode: Text.WrapAnywhere
                        maximumLineCount: 3
                        elide: Text.ElideRight
                    }

                    // facts strip
                    Flow {
                        Layout.fillWidth: true
                        spacing: 10

                        Repeater {
                            model: [
                                {
                                    k: "pid",
                                    v: String(rowWrap.modelData.pid)
                                },
                                {
                                    k: "ppid",
                                    v: String(rowWrap.modelData.ppid)
                                },
                                {
                                    k: "state",
                                    v: rowWrap.modelData.state
                                },
                                {
                                    k: "thr",
                                    v: String(rowWrap.modelData.threads)
                                },
                                {
                                    k: "nice",
                                    v: String(rowWrap.modelData.nice)
                                },
                                {
                                    k: "cpu",
                                    v: rowWrap.modelData.cpu.toFixed(1) + "% (" + (rowWrap.modelData.cpu / Sys.ncpu).toFixed(1) + "% of box)"
                                }
                            ]

                            // `parent` here is the Flow, not this delegate, so the
                            // fields must go through the delegate's own id.
                            Row {
                                id: fact
                                required property var modelData
                                spacing: 3

                                Text {
                                    text: fact.modelData.k
                                    color: Theme.fgFaint
                                    font.family: Theme.font
                                    font.pixelSize: Theme.fsXs
                                }

                                Text {
                                    text: fact.modelData.v
                                    color: Theme.fg
                                    font.family: Theme.font
                                    font.pixelSize: Theme.fsXs
                                }
                            }
                        }
                    }

                    // actions
                    Flow {
                        Layout.fillWidth: true
                        spacing: 4

                        Repeater {
                            model: {
                                const d = rowWrap.modelData;
                                const acts = [];
                                acts.push({
                                    t: "terminate",
                                    c: "warn",
                                    danger: true
                                });
                                acts.push({
                                    t: "force kill",
                                    c: "crit",
                                    danger: true
                                });
                                if (d.state === "T")
                                    acts.push({
                                        t: "resume",
                                        c: "ok",
                                        danger: false
                                    });
                                else
                                    acts.push({
                                        t: "suspend",
                                        c: "dim",
                                        danger: false
                                    });
                                acts.push({
                                    t: "nice +5",
                                    c: "dim",
                                    danger: false
                                });
                                acts.push({
                                    t: "nice −5",
                                    c: "dim",
                                    danger: false
                                });
                                acts.push({
                                    t: "copy pid",
                                    c: "dim",
                                    danger: false
                                });
                                acts.push({
                                    t: "copy cmd",
                                    c: "dim",
                                    danger: false
                                });
                                if (d.count > 1)
                                    acts.push({
                                        t: "kill all ×" + d.count,
                                        c: "crit",
                                        danger: true
                                    });
                                return acts;
                            }

                            Rectangle {
                                id: btn
                                required property var modelData
                                readonly property bool armed: btn.modelData.danger && card.confirmPid === rowWrap.modelData.pid && card.armedAction === btn.modelData.t
                                readonly property color tint: modelData.c === "crit" ? Theme.crit : modelData.c === "warn" ? Theme.warn : modelData.c === "ok" ? Theme.ok : Theme.fgDim

                                implicitWidth: btxt.implicitWidth + 12
                                implicitHeight: 17
                                radius: 3
                                color: armed ? Theme.a(tint, 0.3) : (bma.containsMouse ? Theme.a(tint, 0.18) : "transparent")
                                border.width: 1
                                border.color: armed ? tint : (bma.containsMouse ? Theme.a(tint, 0.6) : Theme.a(tint, 0.28))

                                Text {
                                    id: btxt
                                    anchors.centerIn: parent
                                    text: btn.armed ? "sure?" : btn.modelData.t
                                    color: btn.tint
                                    font.family: Theme.font
                                    font.pixelSize: Theme.fsXs
                                    font.weight: btn.armed ? Font.Bold : Font.Normal
                                }

                                MouseArea {
                                    id: bma
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        const d = rowWrap.modelData;
                                        const t = btn.modelData.t;

                                        // Destructive actions arm on first click and
                                        // fire on the second.
                                        if (btn.modelData.danger && !btn.armed) {
                                            card.confirmPid = d.pid;
                                            card.armedAction = t;
                                            card.say("click again to " + t);
                                            return;
                                        }

                                        if (t === "terminate")
                                            Sys.killPid(d.pid, false);
                                        else if (t === "force kill")
                                            Sys.killPid(d.pid, true);
                                        else if (t === "suspend")
                                            Sys.stopPid(d.pid);
                                        else if (t === "resume")
                                            Sys.contPid(d.pid);
                                        else if (t === "nice +5")
                                            Sys.renicePid(d.pid, 5);
                                        else if (t === "nice −5")
                                            Sys.renicePid(d.pid, -5);
                                        else if (t === "copy pid") {
                                            Sys.copyPid(d.pid);
                                            card.say("copied pid " + d.pid);
                                        } else if (t === "copy cmd") {
                                            Sys.copyText(d.cmd);
                                            card.say("copied cmdline");
                                        } else if (t.indexOf("kill all") === 0)
                                            Sys.killGroup(d.name, true);

                                        card.confirmPid = 0;
                                        card.armedAction = "";
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    property string armedAction: ""

    // -------------------------------------------------------------- footer -- //
    Text {
        Layout.fillWidth: true
        Layout.topMargin: 2
        text: card.lastMsg.length > 0 ? card.lastMsg : "click a row for actions · right-click copies pid · click a column to sort"
        color: card.lastMsg.length > 0 ? (card.lastErr ? Theme.crit : Theme.ok) : Theme.fgFaint
        font.family: Theme.font
        font.pixelSize: Theme.fsXs
        elide: Text.ElideRight
    }
}
