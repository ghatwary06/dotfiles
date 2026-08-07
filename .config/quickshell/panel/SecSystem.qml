import QtQuick
import QtQuick.Layouts

// Full system monitor: CPU (+ per-core strip and temp), memory, NVIDIA GPU,
// and a live process list sorted by CPU.
ColumnLayout {
    id: sec
    spacing: Theme.gap

    WCard {
        title: "PROCESSOR"
        hint: Sys.cpuTemp > 0 ? Sys.cpuTemp + "°C" : ""

        WMeter {
            label: "CPU"
            value: Sys.cpu
            detail: "load " + Sys.load
        }

        // Per-core strip — one thin column per thread.
        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 2
            spacing: 3

            Repeater {
                model: Sys.cores

                Rectangle {
                    required property var modelData

                    Layout.fillWidth: true
                    implicitHeight: 20
                    radius: 1
                    color: Theme.bg2

                    Rectangle {
                        anchors.bottom: parent.bottom
                        width: parent.width
                        height: Math.max(1, parent.height * Math.max(0, Math.min(100, modelData)) / 100)
                        radius: 1
                        color: modelData >= 90 ? Theme.crit : modelData >= 70 ? Theme.warn : Theme.a(Theme.acc, 0.8)

                        Behavior on height {
                            NumberAnimation {
                                duration: Theme.animFast
                            }
                        }
                    }
                }
            }
        }

        Text {
            text: "uptime " + Sys.uptime
            color: Theme.fgFaint
            font.family: Theme.font
            font.pixelSize: Theme.fsXs
            Layout.topMargin: 2
        }
    }

    WCard {
        title: "MEMORY"

        WMeter {
            label: "RAM"
            value: Sys.memPct
            detail: Sys.gib(Sys.memUsed) + " / " + Sys.gib(Sys.memTotal) + " GiB"
        }

        WMeter {
            label: "Swap"
            value: Sys.swapPct
            visible: Sys.swapTotal > 0
            detail: Sys.gib(Sys.swapUsed) + " / " + Sys.gib(Sys.swapTotal) + " GiB"
        }
    }

    WCard {
        title: "GPU"
        hint: Sys.gpuPresent ? Sys.gpuName : "unavailable"
        visible: Sys.gpuPresent

        WMeter {
            label: "Core"
            value: Sys.gpu
            detail: Sys.gpuTemp + "°C  ·  " + Sys.gpuPower.toFixed(1) + "W"
        }

        WMeter {
            label: "VRAM"
            value: Sys.vramTotal > 0 ? Sys.vramUsed * 100 / Sys.vramTotal : 0
            detail: Sys.vramUsed + " / " + Sys.vramTotal + " MiB"
        }
    }

    // Power profile, battery, thermal knobs, fans, keyboard light. Sits ABOVE
    // the process table because it is the thing you act on; the table is what
    // you consult afterwards.
    SecPower {}

    // Interactive: filter, sort, grouping, per-process actions. Own file.
    SecProcs {}
}
