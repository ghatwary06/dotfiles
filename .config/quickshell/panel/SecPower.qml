import QtQuick
import QtQuick.Layouts

// Power, battery and thermal control.
//
// This replaced a CPU/GPU/MEM meter strip that sat directly under the
// PROCESSOR / MEMORY / GPU cards and showed the same three numbers twice.
//
// Everything writable here goes through powerctl.sh and works as the normal
// user (ppd + asusd hold the privilege). Two things are shown but deliberately
// NOT settable:
//   * charge limit — root-owned sysfs, and this asusctl has no charge command
//   * GPU MUX / dGPU — need a reboot, and a wrong click can black-screen the box
WCard {
    id: card

    readonly property var p: Sys.power || ({})
    readonly property var b: Sys.bat || ({})
    property string msg: ""
    property bool err: false

    title: "POWER"
    hint: (p.profile || "—")

    function say(m, bad) {
        msg = m;
        err = bad === true;
        msgTimer.restart();
    }

    Connections {
        target: Sys
        function onPowerActed(what, ok) {
            card.say(ok ? what + " applied" : what + " failed", !ok);
        }
    }

    Timer {
        id: msgTimer
        interval: 3000
        onTriggered: card.msg = ""
    }

    // ------------------------------------------------------- profile switch -- //
    RowLayout {
        Layout.fillWidth: true
        spacing: 4

        Repeater {
            // ppd's own names. platform_profile calls the first one "quiet",
            // but ppd owns that knob so its vocabulary is what we send.
            model: [
                {
                    id: "power-saver",
                    label: "QUIET",
                    icon: "󰌪"
                },
                {
                    id: "balanced",
                    label: "BALANCED",
                    icon: "󰾅"
                },
                {
                    id: "performance",
                    label: "PERF",
                    icon: "󰓅"
                }
            ]

            Rectangle {
                id: pb
                required property var modelData
                readonly property bool on: card.p.profile === modelData.id

                Layout.fillWidth: true
                implicitHeight: 30
                radius: Theme.radiusSm
                color: on ? Theme.a(Theme.acc, 0.20) : (pma.containsMouse ? Theme.a(Theme.chipHi, 0.8) : Theme.a(Theme.bg2, 0.45))
                border.width: 1
                border.color: on ? Theme.a(Theme.acc, 0.65) : Theme.bdr

                Behavior on color {
                    ColorAnimation {
                        duration: Theme.animFast
                    }
                }

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 0

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: pb.modelData.icon
                        color: pb.on ? Theme.acc : Theme.fgDim
                        font.family: Theme.font
                        font.pixelSize: Theme.fsSm
                    }

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: pb.modelData.label
                        color: pb.on ? Theme.acc : Theme.fgFaint
                        font.family: Theme.font
                        font.pixelSize: 9
                        font.weight: pb.on ? Font.Bold : Font.Normal
                        font.letterSpacing: 0.6
                    }
                }

                MouseArea {
                    id: pma
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Sys.setProfile(pb.modelData.id)
                }
            }
        }
    }

    // -------------------------------------------------------------- battery -- //
    RowLayout {
        Layout.fillWidth: true
        Layout.topMargin: 2
        spacing: 6
        visible: card.b.present === true

        Text {
            text: card.b.ac === 1 ? "󰚥" : (card.b.pct >= 80 ? "󰁹" : card.b.pct >= 50 ? "󰁿" : card.b.pct >= 20 ? "󰁽" : "󰁺")
            color: card.b.ac === 1 ? Theme.ok : card.b.pct <= 20 ? Theme.crit : Theme.fgDim
            font.family: Theme.font
            font.pixelSize: Theme.fsMd
        }

        Text {
            text: (card.b.pct || 0) + "%"
            color: Theme.fg
            font.family: Theme.font
            font.pixelSize: Theme.fsMd
            font.weight: Font.Bold
        }

        // Track: fill to charge %, with a tick marking the charge limit so it is
        // obvious WHY it stops at 80 and is not treated as a fault.
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 6
            radius: 3
            color: Theme.a(Theme.bg2, 0.9)

            Rectangle {
                width: parent.width * Math.max(0, Math.min(100, card.b.pct || 0)) / 100
                height: parent.height
                radius: 3
                color: card.b.pct <= 20 ? Theme.crit : card.b.ac === 1 ? Theme.ok : Theme.acc

                Behavior on width {
                    NumberAnimation {
                        duration: Theme.animSlide
                    }
                }
            }

            Rectangle {
                visible: (card.b.limit || 0) > 0 && card.b.limit < 100
                x: parent.width * (card.b.limit || 100) / 100 - 1
                width: 2
                height: parent.height + 4
                y: -2
                color: Theme.warn
                opacity: 0.9
            }
        }

        Text {
            text: card.b.status === "Discharging" && card.b.draw > 0 ? (card.b.draw / 100).toFixed(1) + "W" : (card.b.status || "")
            color: Theme.fgFaint
            font.family: Theme.font
            font.pixelSize: Theme.fsXs
        }
    }

    // battery detail line
    RowLayout {
        Layout.fillWidth: true
        spacing: 10
        visible: card.b.present === true

        Repeater {
            model: [
                {
                    k: "",
                    v: ((card.b.energy || 0) / 100).toFixed(1) + " / " + ((card.b.full || 0) / 100).toFixed(1) + " Wh"
                },
                {
                    k: "health",
                    v: (card.b.design > 0 ? Math.round((card.b.full / card.b.design) * 100) : 0) + "%"
                },
                {
                    k: "limit",
                    v: (card.b.limit || 0) + "%"
                },
                {
                    k: "cycles",
                    v: String(card.b.cycles || 0)
                }
            ]

            Row {
                id: bfact
                required property var modelData
                spacing: 3

                Text {
                    text: bfact.modelData.k
                    color: Theme.fgFaint
                    font.family: Theme.font
                    font.pixelSize: Theme.fsXs
                    visible: text.length > 0
                }

                Text {
                    text: bfact.modelData.v
                    color: Theme.fgDim
                    font.family: Theme.font
                    font.pixelSize: Theme.fsXs
                }
            }
        }

        Item {
            Layout.fillWidth: true
        }
    }

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: 1
        color: Theme.bdr
    }

    // -------------------------------------------------------------- thermal -- //
    // READ-ONLY on this machine, verified 2026-08-06 — do not "fix" by adding
    // buttons back without re-testing.
    //
    // `asusctl armoury set <attr> <val>` returns exit 0 and asusd's D-Bus
    // CurrentValue does change, but the kernel attribute under
    // /sys/class/firmware-attributes/asus-armoury/attributes/<attr>/current_value
    // NEVER moves — so the setting never reaches the firmware. Confirmed on both
    // a CPU attr (ppt_pl1_spl 115 -> asusd says 110, sysfs stays 115) and a GPU
    // attr (nv_temp_target 87 -> asusd says 85, sysfs stays 87).
    // xyz.ljones.AsusArmoury.ApplyQueuedGpuValue() returns FALSE, so the queued
    // GPU path is not the missing step either. Looks like an asusd/kernel
    // asus-armoury version mismatch.
    //
    // Shipping steppers here would be a lie: they would light up, report
    // "applied", and change nothing. Writing the sysfs files directly WOULD work
    // (they are root-owned rw) but needs a polkit rule or sudoers entry.
    //
    // Re-test with:
    //   asusctl armoury set ppt_pl1_spl 110; sleep 1
    //   cat /sys/class/firmware-attributes/asus-armoury/attributes/ppt_pl1_spl/current_value
    Repeater {
        // `attr` is the asus-armoury sysfs name used for WRITES; `key` is the
        // (shorter) field sysinfo.sh puts in the JSON, used for READS. They are
        // NOT the same string, and conflating them is actively dangerous: the
        // read silently falls back to `min`, so a single "+" click would compute
        // min+step and write 33W to a CPU actually sitting at 115W.
        model: [
            {
                attr: "ppt_pl1_spl",
                key: "pl1",
                label: "CPU sustained",
                unit: "W",
                min: 28,
                max: 135,
                step: 5
            },
            {
                attr: "ppt_pl2_sppt",
                key: "pl2",
                label: "CPU burst",
                unit: "W",
                min: 28,
                max: 135,
                step: 5
            },
            {
                attr: "nv_dynamic_boost",
                key: "nvBoost",
                label: "GPU boost",
                unit: "W",
                min: 5,
                max: 25,
                step: 5
            },
            {
                attr: "nv_temp_target",
                key: "nvTemp",
                label: "GPU temp cap",
                unit: "°C",
                min: 75,
                max: 87,
                step: 1
            }
        ]

        RowLayout {
            id: knob
            required property var modelData
            // -1 when the value has not arrived yet, so the steppers stay inert
            // rather than acting on a fabricated baseline.
            readonly property int val: card.p[modelData.key] !== undefined ? card.p[modelData.key] : -1
            readonly property bool ready: val >= modelData.min

            Layout.fillWidth: true
            spacing: 6

            Text {
                text: knob.modelData.label
                color: Theme.fgDim
                font.family: Theme.font
                font.pixelSize: Theme.fsXs
                Layout.preferredWidth: 92
            }

            // fill bar showing where the value sits in its range
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 4
                radius: 2
                color: Theme.a(Theme.bg2, 0.9)

                Rectangle {
                    width: knob.ready ? parent.width * Math.max(0, Math.min(1, (knob.val - knob.modelData.min) / (knob.modelData.max - knob.modelData.min))) : 0
                    height: parent.height
                    radius: 2
                    color: Theme.acc

                    Behavior on width {
                        NumberAnimation {
                            duration: Theme.animFast
                        }
                    }
                }
            }

            Text {
                text: knob.ready ? knob.val + knob.modelData.unit : "—"
                color: Theme.fg
                font.family: Theme.font
                font.pixelSize: Theme.fsXs
                horizontalAlignment: Text.AlignRight
                Layout.preferredWidth: 40
            }
        }
    }

    Text {
        Layout.fillWidth: true
        text: "read-only · asusd accepts these but they never reach firmware"
        color: Theme.fgFaint
        font.family: Theme.font
        font.pixelSize: Theme.fsXs
        elide: Text.ElideRight
    }

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: 1
        color: Theme.bdr
    }

    // ------------------------------------------------------ fans / leds / mux -- //
    RowLayout {
        Layout.fillWidth: true
        spacing: 10

        Text {
            text: "󰈐"
            color: Theme.fgDim
            font.family: Theme.font
            font.pixelSize: Theme.fsSm
        }

        Text {
            text: "cpu " + (card.p.fanCpu || 0) + "  gpu " + (card.p.fanGpu || 0) + " rpm"
            color: Theme.fgDim
            font.family: Theme.font
            font.pixelSize: Theme.fsXs
        }

        Item {
            Layout.fillWidth: true
        }

        // keyboard backlight — cycles off/low/med/high through asusctl
        Rectangle {
            implicitWidth: kbdRow.implicitWidth + 12
            implicitHeight: 18
            radius: 3
            color: kma.containsMouse ? Theme.a(Theme.acc, 0.18) : Theme.a(Theme.bg2, 0.5)
            border.width: 1
            border.color: kma.containsMouse ? Theme.a(Theme.acc, 0.6) : Theme.bdr

            Row {
                id: kbdRow
                anchors.centerIn: parent
                spacing: 4

                Text {
                    text: "󰌌"
                    color: (card.p.kbdLed || 0) > 0 ? Theme.acc : Theme.fgFaint
                    font.family: Theme.font
                    font.pixelSize: Theme.fsSm
                }

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2

                    Repeater {
                        model: card.p.kbdLedMax || 3

                        Rectangle {
                            required property int index
                            width: 4
                            height: 4
                            radius: 2
                            color: index < (card.p.kbdLed || 0) ? Theme.acc : Theme.a(Theme.fgFaint, 0.35)
                        }
                    }
                }
            }

            MouseArea {
                id: kma
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Sys.cycleKbd()
            }
        }
    }

    // GPU mode — READ ONLY. Switching needs a reboot and a bad click here can
    // leave the machine with no display, so the panel reports and does not act.
    RowLayout {
        Layout.fillWidth: true
        spacing: 6

        Text {
            text: "󰢮"
            color: Theme.fgFaint
            font.family: Theme.font
            font.pixelSize: Theme.fsSm
        }

        Text {
            text: card.p.dgpuOff === 1 ? "dGPU disabled" : card.p.muxMode === 0 ? "Ultimate (dGPU direct)" : "Hybrid (Optimus)"
            color: Theme.fgDim
            font.family: Theme.font
            font.pixelSize: Theme.fsXs
        }

        Text {
            text: card.p.rebootPending === 1 ? "· reboot pending" : "· read-only, needs reboot to change"
            color: card.p.rebootPending === 1 ? Theme.warn : Theme.fgFaint
            font.family: Theme.font
            font.pixelSize: Theme.fsXs
            elide: Text.ElideRight
            Layout.fillWidth: true
        }
    }

    Text {
        Layout.fillWidth: true
        text: card.msg
        visible: card.msg.length > 0
        color: card.err ? Theme.crit : Theme.ok
        font.family: Theme.font
        font.pixelSize: Theme.fsXs
        elide: Text.ElideRight
    }
}
