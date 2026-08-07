import QtQuick
import QtQuick.Layouts

// Framed section container: hairline border, small radius, monospace caption.
Rectangle {
    id: card

    property string title: ""
    property string hint: ""
    default property alias content: slot.data

    color: Theme.cardBg
    border.color: Theme.bdr
    border.width: 1
    radius: Theme.radius

    Layout.fillWidth: true
    implicitHeight: body.implicitHeight + Theme.pad * 2

    ColumnLayout {
        id: body
        anchors.fill: parent
        anchors.margins: Theme.pad
        spacing: Theme.gap

        RowLayout {
            Layout.fillWidth: true
            visible: card.title.length > 0
            spacing: Theme.gap

            Text {
                text: card.title
                color: Theme.fgDim
                font.family: Theme.font
                font.pixelSize: Theme.fsXs
                font.weight: Font.DemiBold
                font.letterSpacing: 1.2
            }

            // Hairline rule filling the remaining width of the caption row.
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 1
                color: Theme.bdr
            }

            Text {
                text: card.hint
                visible: card.hint.length > 0
                color: Theme.fgFaint
                font.family: Theme.font
                font.pixelSize: Theme.fsXs
            }
        }

        ColumnLayout {
            id: slot
            Layout.fillWidth: true
            spacing: 6
        }
    }
}
