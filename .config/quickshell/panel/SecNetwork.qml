import QtQuick
import QtQuick.Layouts

// Connection identity, addressing and live throughput.
ColumnLayout {
    id: sec
    spacing: Theme.gap

    WCard {
        title: "NETWORK"
        hint: Sys.netIface

        WKV {
            k: "Connection"
            v: Sys.netConn || "—"
            vColor: Sys.netConn ? Theme.acc : Theme.fgDim
        }

        WKV {
            k: "Type"
            v: Sys.netType === "wifi" ? "Wi-Fi  ·  " + Sys.netSignal + "%" : (Sys.netType || "—")
        }

        WKV {
            k: "Local IP"
            v: Sys.netIp || "—"
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.gap

            Text {
                text: "Public IP"
                color: Theme.fgDim
                font.family: Theme.font
                font.pixelSize: Theme.fsSm
                Layout.minimumWidth: 84
            }

            Item {
                Layout.fillWidth: true
            }

            // Not fetched automatically — resolving it means talking to a third
            // party, so it stays an explicit action.
            Text {
                text: Sys.publicIpLoading ? "…" : (Sys.publicIp || "reveal")
                color: Sys.publicIp ? Theme.fg : Theme.accDim
                font.family: Theme.font
                font.pixelSize: Theme.fsSm
                font.underline: !Sys.publicIp && !Sys.publicIpLoading

                MouseArea {
                    anchors.fill: parent
                    enabled: !Sys.publicIp && !Sys.publicIpLoading
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Sys.fetchPublicIp()
                }
            }
        }
    }

    WCard {
        title: "THROUGHPUT"

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.gap

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                Text {
                    text: "  down"
                    color: Theme.fgDim
                    font.family: Theme.font
                    font.pixelSize: Theme.fsXs
                }

                Text {
                    text: Sys.rate(Sys.rxRate)
                    color: Theme.acc
                    font.family: Theme.font
                    font.pixelSize: Theme.fsLg
                }
            }

            Rectangle {
                implicitWidth: 1
                Layout.fillHeight: true
                Layout.preferredHeight: 34
                color: Theme.bdr
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                Text {
                    text: "  up"
                    color: Theme.fgDim
                    font.family: Theme.font
                    font.pixelSize: Theme.fsXs
                }

                Text {
                    text: Sys.rate(Sys.txRate)
                    color: Theme.fg
                    font.family: Theme.font
                    font.pixelSize: Theme.fsLg
                }
            }
        }

        Text {
            // Kernel counters — these reset when the link goes down, not at login.
            text: "since link up  ↓ " + (Sys._rx / 1073741824).toFixed(2) + " GiB   ↑ " + (Sys._tx / 1073741824).toFixed(2) + " GiB"
            color: Theme.fgFaint
            font.family: Theme.font
            font.pixelSize: Theme.fsXs
        }
    }
}
