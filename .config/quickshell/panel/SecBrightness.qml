import QtQuick
import QtQuick.Layouts

// Brightness sliders, one per display.
//
// Pinned alongside the quick toggles rather than buried in a tab: brightness is
// something you reach for constantly, and it should not depend on which tab
// happens to be open.
//
// Hand-rolled sliders to match the rest of the rice (same approach as the
// dashboard seek bar) — a 4px visual rail inside a 20px hit area, because a 4px
// drag target is miserable to hit.
ColumnLayout {
    id: sec
    spacing: 6

    Component.onCompleted: Brightness.refresh()

    RowLayout {
        Layout.fillWidth: true
        spacing: Theme.gap

        Text {
            text: "BRIGHTNESS"
            color: Theme.fgDim
            font.family: Theme.font
            font.pixelSize: Theme.fsXs
            font.weight: Font.DemiBold
            font.letterSpacing: 1.2
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 1
            color: Theme.bdr
        }

        // Only meaningful for the external one — the backlight is instant.
        Text {
            text: Brightness.externalBusy ? "syncing…" : ""
            color: Theme.fgFaint
            font.family: Theme.font
            font.pixelSize: Theme.fsXs
        }
    }

    Repeater {
        model: [
            {
                key: "laptop",
                icon: "󰌢",
                label: "laptop"
            },
            {
                key: "external",
                icon: "󰍹",
                label: "monitor"
            }
        ]

        RowLayout {
            id: row
            required property var modelData
            readonly property bool isExt: modelData.key === "external"
            readonly property int value: isExt ? Brightness.external : Brightness.laptop

            Layout.fillWidth: true
            spacing: 8
            // Hide the external row entirely if DDC/CI is not answering, rather
            // than showing a slider that silently does nothing.
            visible: !isExt || Brightness.hasExternal

            Text {
                text: row.modelData.icon
                color: Theme.fgDim
                font.family: Theme.font
                font.pixelSize: Theme.fsMd
                Layout.preferredWidth: 16
            }

            Item {
                id: track
                Layout.fillWidth: true
                implicitHeight: 20

                readonly property real frac: Math.max(0, Math.min(1, row.value / 100))

                Rectangle {
                    id: rail
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    height: 4
                    radius: 2
                    color: Theme.a(Theme.bg2, 0.9)

                    Rectangle {
                        width: parent.width * track.frac
                        height: parent.height
                        radius: parent.radius
                        color: Theme.acc

                        // No animation while dragging — the fill must track the
                        // cursor exactly or the control feels broken.
                        Behavior on width {
                            enabled: !drag.pressed
                            NumberAnimation {
                                duration: Theme.animFast
                            }
                        }
                    }
                }

                Rectangle {
                    id: handle
                    width: 10
                    height: 10
                    radius: 5
                    color: drag.pressed || drag.containsMouse ? Theme.acc : Theme.fg
                    border.width: 1
                    border.color: Theme.a(Theme.bg0, 0.8)
                    anchors.verticalCenter: parent.verticalCenter
                    x: Math.max(0, Math.min(parent.width - width, track.frac * parent.width - width / 2))

                    Behavior on x {
                        enabled: !drag.pressed
                        NumberAnimation {
                            duration: Theme.animFast
                        }
                    }
                }

                MouseArea {
                    id: drag
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor

                    function apply(mx) {
                        const pct = Math.round(Math.max(0, Math.min(1, mx / width)) * 100);
                        if (row.isExt)
                            Brightness.setExternal(pct);
                        else
                            Brightness.setLaptop(pct);
                    }

                    onPressed: m => apply(m.x)
                    onPositionChanged: m => {
                        if (pressed)
                            apply(m.x);
                    }
                    // Scroll for fine adjustment without aiming at the handle.
                    onWheel: w => {
                        const step = w.angleDelta.y > 0 ? 5 : -5;
                        if (row.isExt)
                            Brightness.setExternal(row.value + step);
                        else
                            Brightness.setLaptop(row.value + step);
                    }
                }
            }

            Text {
                text: row.value + "%"
                color: Theme.fg
                font.family: Theme.font
                font.pixelSize: Theme.fsXs
                horizontalAlignment: Text.AlignRight
                Layout.preferredWidth: 32
            }
        }
    }
}
