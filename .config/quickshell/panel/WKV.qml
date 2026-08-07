import QtQuick
import QtQuick.Layouts

// Key / value line. Values are selectable so IPs can be copied out.
RowLayout {
    id: kv

    property string k: ""
    property string v: ""
    property color vColor: Theme.fg
    property bool mono: true

    Layout.fillWidth: true
    spacing: Theme.gap

    Text {
        text: kv.k
        color: Theme.fgDim
        font.family: Theme.font
        font.pixelSize: Theme.fsSm
        Layout.minimumWidth: 84
    }

    TextEdit {
        text: kv.v
        color: kv.vColor
        font.family: Theme.font
        font.pixelSize: Theme.fsSm
        readOnly: true
        selectByMouse: true
        selectionColor: Theme.a(Theme.acc, 0.3)
        selectedTextColor: Theme.fg
        wrapMode: TextEdit.NoWrap
        Layout.fillWidth: true
        horizontalAlignment: TextEdit.AlignRight
    }
}
