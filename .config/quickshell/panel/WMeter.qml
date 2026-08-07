import QtQuick
import QtQuick.Layouts

// Label / value row with a thin fill bar underneath.
// Tint shifts amber → red past the thresholds, the only time a second hue appears.
Item {
    id: meter

    property string label: ""
    property real value: 0              // 0..100
    property string detail: ""
    property int warnAt: 75
    property int critAt: 90

    readonly property color tint: value >= critAt ? Theme.crit : value >= warnAt ? Theme.warn : Theme.acc

    Layout.fillWidth: true
    implicitHeight: col.implicitHeight

    ColumnLayout {
        id: col
        width: parent.width
        spacing: 4

        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            Text {
                text: meter.label
                color: Theme.fg
                font.family: Theme.font
                font.pixelSize: Theme.fsSm
            }

            Item {
                Layout.fillWidth: true
            }

            Text {
                text: meter.detail
                color: Theme.fgDim
                font.family: Theme.font
                font.pixelSize: Theme.fsXs
            }

            Text {
                text: Math.round(meter.value) + "%"
                color: meter.tint
                font.family: Theme.font
                font.pixelSize: Theme.fsSm
                font.weight: Font.DemiBold
                horizontalAlignment: Text.AlignRight
                Layout.minimumWidth: 34
            }
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 3
            radius: 1.5
            color: Theme.bg2

            Rectangle {
                width: parent.width * Math.max(0, Math.min(100, meter.value)) / 100
                height: parent.height
                radius: parent.radius
                color: meter.tint

                Behavior on width {
                    NumberAnimation {
                        duration: Theme.animFast
                        easing.type: Easing.OutQuad
                    }
                }
                Behavior on color {
                    ColorAnimation {
                        duration: Theme.animFast
                    }
                }
            }
        }
    }
}
