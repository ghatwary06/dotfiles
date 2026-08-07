import QtQuick
import QtQuick.Layouts

// Square-ish quick toggle. Off reads as a dim outline; on fills faintly with
// the accent — the only colour shift in the tile, so state is obvious at a glance.
Rectangle {
    id: tile

    property string icon: ""
    property string label: ""
    property string sub: ""
    property bool on: false
    property bool busy: false

    signal activated
    signal secondary

    Layout.fillWidth: true
    implicitHeight: 52
    radius: Theme.radiusSm
    color: on ? Theme.a(Theme.acc, 0.11) : Theme.a(Theme.bg2, 0.55)
    border.width: 1
    border.color: on ? Theme.a(Theme.acc, 0.45) : Theme.bdr

    Behavior on color {
        ColorAnimation {
            duration: Theme.animFast
        }
    }
    Behavior on border.color {
        ColorAnimation {
            duration: Theme.animFast
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 10
        anchors.rightMargin: 10
        spacing: 9

        Text {
            text: tile.icon
            color: tile.on ? Theme.acc : Theme.fgDim
            font.family: Theme.font
            font.pixelSize: 16
            opacity: tile.busy ? 0.45 : 1

            Behavior on color {
                ColorAnimation {
                    duration: Theme.animFast
                }
            }
        }

        ColumnLayout {
            spacing: 1
            Layout.fillWidth: true

            Text {
                text: tile.label
                color: tile.on ? Theme.fg : Theme.fgDim
                font.family: Theme.font
                font.pixelSize: Theme.fsSm
                font.weight: Font.DemiBold
                elide: Text.ElideRight
                Layout.fillWidth: true
            }

            Text {
                text: tile.sub
                visible: tile.sub.length > 0
                color: Theme.fgFaint
                font.family: Theme.font
                font.pixelSize: Theme.fsXs
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        hoverEnabled: true
        onEntered: tile.opacity = 0.88
        onExited: tile.opacity = 1
        onClicked: function (mouse) {
            if (mouse.button === Qt.RightButton)
                tile.secondary();
            else
                tile.activated();
        }
    }

    Behavior on opacity {
        NumberAnimation {
            duration: Theme.animFast
        }
    }
}
