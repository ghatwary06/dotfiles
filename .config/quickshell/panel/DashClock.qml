import QtQuick
import QtQuick.Layouts

// Big clock + weather summary, side by side. This is the top of the dashboard
// and carries most of its visual weight, so the time is set large and the
// seconds run in the accent to give it a pulse.
Rectangle {
    id: head

    property date now: new Date()

    Layout.fillWidth: true
    implicitHeight: 104
    radius: Theme.radius
    color: Theme.cardBg
    border.width: 1
    border.color: Theme.bdr

    Timer {
        interval: 1000
        repeat: true
        running: head.visible
        triggeredOnStart: true
        onTriggered: head.now = new Date()
    }

    function pad(n) {
        return n < 10 ? "0" + n : "" + n;
    }

    // 12-hour, to match the bar clock. Midnight/noon are hour 0 and 12 in
    // 24h terms and BOTH must render as 12, which a plain `h % 12` gets wrong
    // for midnight (it yields 0).
    function hour12(d) {
        const h = d.getHours() % 12;
        return h === 0 ? 12 : h;
    }

    function meridiem(d) {
        return d.getHours() < 12 ? "AM" : "PM";
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: Theme.pad + 2
        spacing: Theme.pad

        // -- time ------------------------------------------------------------
        ColumnLayout {
            spacing: 0
            Layout.alignment: Qt.AlignVCenter

            RowLayout {
                spacing: 3
                Layout.alignment: Qt.AlignLeft

                Text {
                    // Hour is NOT zero-padded in 12-hour form — "07:15 PM" reads
                    // like a 24h clock that lost its way.
                    text: head.hour12(head.now) + ":" + head.pad(head.now.getMinutes())
                    color: Theme.fg
                    font.family: Theme.font
                    font.pixelSize: 40
                    font.weight: Font.Bold
                    font.letterSpacing: -1
                }

                ColumnLayout {
                    spacing: 0
                    Layout.alignment: Qt.AlignBottom
                    Layout.bottomMargin: 5

                    Text {
                        text: head.meridiem(head.now)
                        color: Theme.fgDim
                        font.family: Theme.font
                        font.pixelSize: 11
                        font.weight: Font.DemiBold
                    }

                    Text {
                        text: head.pad(head.now.getSeconds())
                        color: Theme.acc
                        font.family: Theme.font
                        font.pixelSize: 15
                        font.weight: Font.DemiBold
                    }
                }
            }

            Text {
                text: Qt.formatDate(head.now, "dddd, d MMMM yyyy").toLowerCase()
                color: Theme.fgDim
                font.family: Theme.font
                font.pixelSize: Theme.fsSm
            }
        }

        Item {
            Layout.fillWidth: true
        }

        // -- vertical rule ---------------------------------------------------
        Rectangle {
            implicitWidth: 1
            Layout.preferredHeight: 62
            color: Theme.bdr
            visible: Weather.ok
        }

        // -- weather ---------------------------------------------------------
        RowLayout {
            spacing: 10
            visible: Weather.ok
            Layout.alignment: Qt.AlignVCenter

            Text {
                text: Weather.icon
                color: Theme.acc
                font.family: Theme.font
                font.pixelSize: 34
            }

            ColumnLayout {
                spacing: 1

                Text {
                    text: Weather.temp + "°C"
                    color: Theme.fg
                    font.family: Theme.font
                    font.pixelSize: 20
                    font.weight: Font.DemiBold
                }

                Text {
                    text: Weather.desc.toLowerCase()
                    color: Theme.fgDim
                    font.family: Theme.font
                    font.pixelSize: Theme.fsXs
                    elide: Text.ElideRight
                    Layout.maximumWidth: 130
                }

                Text {
                    text: Weather.tmin + "° / " + Weather.tmax + "°  ·  " + Weather.area
                    color: Theme.fgFaint
                    font.family: Theme.font
                    font.pixelSize: Theme.fsXs
                    elide: Text.ElideRight
                    Layout.maximumWidth: 150
                }
            }
        }

        // Weather cache missing entirely (first boot before the bar ran, or
        // the fetch failed) — offer the retry rather than showing a blank gap.
        Text {
            visible: !Weather.ok
            text: "weather unavailable\nclick to retry"
            horizontalAlignment: Text.AlignRight
            color: Theme.fgFaint
            font.family: Theme.font
            font.pixelSize: Theme.fsXs

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: Weather.refresh()
            }
        }
    }
}
