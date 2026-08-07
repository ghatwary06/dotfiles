import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts

// Transient notification popups, top-right under waybar.
// The window is sized to its content and unmapped when empty, so it never
// steals clicks from whatever is underneath.
PanelWindow {
    id: win

    anchors {
        top: true
        right: true
    }
    margins {
        top: 44
        right: 10
    }

    implicitWidth: 360
    implicitHeight: Math.max(1, col.implicitHeight)
    exclusiveZone: 0
    color: "transparent"
    visible: Notifs.popups.length > 0

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "qs-toast"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    ColumnLayout {
        id: col
        width: parent.width
        spacing: 6

        Repeater {
            model: Notifs.popups

            Rectangle {
                id: toast
                required property var modelData

                Layout.fillWidth: true
                implicitHeight: inner.implicitHeight + 22
                radius: Theme.radius
                color: Theme.panelBg
                border.width: 1
                border.color: toast.modelData.urgent ? Theme.a(Theme.crit, 0.55) : Theme.bdr

                // Slide in from the right edge.
                opacity: 0
                transform: Translate {
                    id: slide
                    x: 30
                }

                Component.onCompleted: {
                    fadeIn.start();
                    slideIn.start();
                }

                NumberAnimation {
                    id: fadeIn
                    target: toast
                    property: "opacity"
                    to: 1
                    duration: Theme.animSlide
                    easing.type: Easing.OutCubic
                }
                NumberAnimation {
                    id: slideIn
                    target: slide
                    property: "x"
                    to: 0
                    duration: Theme.animSlide
                    easing.type: Easing.OutCubic
                }

                Rectangle {
                    visible: toast.modelData.urgent
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    anchors.margins: 1
                    width: 2
                    radius: 1
                    color: Theme.crit
                }

                ColumnLayout {
                    id: inner
                    anchors.fill: parent
                    anchors.margins: 11
                    spacing: 3

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        Text {
                            text: toast.modelData.appName || "system"
                            color: Theme.accDim
                            font.family: Theme.font
                            font.pixelSize: Theme.fsXs
                            font.weight: Font.DemiBold
                        }

                        Item {
                            Layout.fillWidth: true
                        }

                        Text {
                            text: "󰅖"
                            color: xMa.containsMouse ? Theme.crit : Theme.fgFaint
                            font.family: Theme.font
                            font.pixelSize: Theme.fsSm

                            MouseArea {
                                id: xMa
                                anchors.fill: parent
                                anchors.margins: -4
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Notifs.dismiss(toast.modelData.key)
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 9

                        Image {
                            visible: toast.modelData.image.length > 0
                            source: toast.modelData.image
                            sourceSize.width: 32
                            sourceSize.height: 32
                            Layout.preferredWidth: 32
                            Layout.preferredHeight: 32
                            Layout.alignment: Qt.AlignTop
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1

                            Text {
                                text: toast.modelData.summary
                                visible: text.length > 0
                                color: Theme.fg
                                font.family: Theme.font
                                font.pixelSize: Theme.fsSm
                                font.weight: Font.DemiBold
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }

                            Text {
                                text: toast.modelData.body
                                visible: text.length > 0
                                color: Theme.fgDim
                                font.family: Theme.font
                                font.pixelSize: Theme.fsSm
                                textFormat: Text.StyledText
                                wrapMode: Text.WordWrap
                                maximumLineCount: 3
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                        }
                    }
                }

                // Click the body to open the panel's notification tab.
                MouseArea {
                    anchors.fill: parent
                    z: -1
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Notifs.opened()
                }
            }
        }
    }
}
