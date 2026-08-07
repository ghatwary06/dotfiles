import QtQuick
import QtQuick.Layouts

// Conditions detail + a three-day outlook. The headline numbers already live
// in DashClock, so this card carries the things you go looking for.
WCard {
    id: wx
    title: "CONDITIONS"
    hint: Weather.ok ? Weather.area + ", " + Weather.country : ""
    visible: Weather.ok

    GridLayout {
        Layout.fillWidth: true
        columns: 4
        columnSpacing: Theme.gap
        rowSpacing: 6

        Repeater {
            model: [
                {
                    k: "feels",
                    v: Weather.feels + "°"
                },
                {
                    k: "humidity",
                    v: Weather.humidity + "%"
                },
                {
                    k: "wind",
                    v: Weather.wind + " " + Weather.windDir
                },
                {
                    k: "uv",
                    v: Weather.uv + " " + Weather.uvLabel()
                },
                {
                    k: "rain",
                    v: Weather.precip + " mm"
                },
                {
                    k: "pressure",
                    v: Weather.pressure + " mb"
                },
                {
                    k: "sunrise",
                    v: Weather.sunrise
                },
                {
                    k: "sunset",
                    v: Weather.sunset
                }
            ]

            ColumnLayout {
                required property var modelData
                Layout.fillWidth: true
                spacing: 0

                Text {
                    text: modelData.k
                    color: Theme.fgFaint
                    font.family: Theme.font
                    font.pixelSize: Theme.fsXs
                }

                Text {
                    text: modelData.v
                    color: Theme.fg
                    font.family: Theme.font
                    font.pixelSize: Theme.fsSm
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
            }
        }
    }

    Rectangle {
        Layout.fillWidth: true
        Layout.topMargin: 2
        implicitHeight: 1
        color: Theme.bdr
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: Theme.gap

        Repeater {
            model: Weather.forecast

            ColumnLayout {
                id: fc
                required property var modelData
                required property int index

                Layout.fillWidth: true
                spacing: 2

                Text {
                    text: fc.index === 0 ? "today" : Weather.dayName(fc.modelData.date)
                    color: fc.index === 0 ? Theme.acc : Theme.fgDim
                    font.family: Theme.font
                    font.pixelSize: Theme.fsXs
                    Layout.alignment: Qt.AlignHCenter
                }

                Text {
                    text: fc.modelData.max + "° / " + fc.modelData.min + "°"
                    color: Theme.fg
                    font.family: Theme.font
                    font.pixelSize: Theme.fsSm
                    Layout.alignment: Qt.AlignHCenter
                }

                Text {
                    text: fc.modelData.desc.toLowerCase()
                    color: Theme.fgFaint
                    font.family: Theme.font
                    font.pixelSize: Theme.fsXs
                    elide: Text.ElideRight
                    horizontalAlignment: Text.AlignHCenter
                    Layout.fillWidth: true
                }
            }
        }
    }
}
