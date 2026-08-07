import QtQuick
import QtQuick.Layouts

// Notification history. Entries stay interactive (their actions are still
// invokable) because Notifs marks each notification as tracked.
ColumnLayout {
    id: sec
    spacing: Theme.gap

    RowLayout {
        Layout.fillWidth: true
        spacing: Theme.gap

        Text {
            text: Notifs.count === 0 ? "NO NOTIFICATIONS" : Notifs.count + (Notifs.count === 1 ? " NOTIFICATION" : " NOTIFICATIONS")
            color: Theme.fgDim
            font.family: Theme.font
            font.pixelSize: Theme.fsXs
            font.weight: Font.DemiBold
            font.letterSpacing: 1.2
        }

        Item {
            Layout.fillWidth: true
        }

        Text {
            text: Notifs.dnd ? "dnd on" : ""
            color: Theme.accDim
            font.family: Theme.font
            font.pixelSize: Theme.fsXs
        }

        Text {
            text: "clear all"
            visible: Notifs.count > 0
            color: clearMa.containsMouse ? Theme.crit : Theme.fgDim
            font.family: Theme.font
            font.pixelSize: Theme.fsXs

            MouseArea {
                id: clearMa
                anchors.fill: parent
                anchors.margins: -4
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Notifs.clearAll()
            }
        }
    }

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: 76
        visible: Notifs.count === 0
        color: "transparent"
        border.color: Theme.bdr
        border.width: 1
        radius: Theme.radius

        Text {
            anchors.centerIn: parent
            text: "󰂜\nnothing here"
            horizontalAlignment: Text.AlignHCenter
            color: Theme.fgFaint
            font.family: Theme.font
            font.pixelSize: Theme.fsSm
            lineHeight: 1.6
        }
    }

    Repeater {
        model: Notifs.items

        Rectangle {
            id: item
            required property var modelData

            Layout.fillWidth: true
            implicitHeight: content.implicitHeight + Theme.pad * 2
            radius: Theme.radius
            color: hov.containsMouse ? Theme.a(Theme.bg2, 0.75) : Theme.cardBg
            border.width: 1
            border.color: item.modelData.urgent ? Theme.a(Theme.crit, 0.5) : Theme.bdr

            Behavior on color {
                ColorAnimation {
                    duration: Theme.animFast
                }
            }

            // Urgency is shown as a hairline spine rather than a coloured card.
            Rectangle {
                visible: item.modelData.urgent
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.margins: 1
                width: 2
                radius: 1
                color: Theme.crit
            }

            MouseArea {
                id: hov
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.NoButton
            }

            ColumnLayout {
                id: content
                anchors.fill: parent
                anchors.margins: Theme.pad
                spacing: 4

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Text {
                        text: item.modelData.appName || "system"
                        color: Theme.accDim
                        font.family: Theme.font
                        font.pixelSize: Theme.fsXs
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                        Layout.maximumWidth: 160
                    }

                    Item {
                        Layout.fillWidth: true
                    }

                    Text {
                        text: Notifs.ageText(item.modelData.time)
                        color: Theme.fgFaint
                        font.family: Theme.font
                        font.pixelSize: Theme.fsXs
                    }

                    Text {
                        text: "󰅖"
                        color: closeMa.containsMouse ? Theme.crit : Theme.fgFaint
                        font.family: Theme.font
                        font.pixelSize: Theme.fsSm

                        MouseArea {
                            id: closeMa
                            anchors.fill: parent
                            anchors.margins: -4
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Notifs.dismiss(item.modelData.key)
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Image {
                        visible: item.modelData.image.length > 0
                        source: item.modelData.image
                        sourceSize.width: 36
                        sourceSize.height: 36
                        Layout.preferredWidth: 36
                        Layout.preferredHeight: 36
                        Layout.alignment: Qt.AlignTop
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        Text {
                            text: item.modelData.summary
                            visible: text.length > 0
                            color: Theme.fg
                            font.family: Theme.font
                            font.pixelSize: Theme.fsSm
                            font.weight: Font.DemiBold
                            wrapMode: Text.WordWrap
                            Layout.fillWidth: true
                        }

                        Text {
                            text: item.modelData.body
                            visible: text.length > 0
                            color: Theme.fgDim
                            font.family: Theme.font
                            font.pixelSize: Theme.fsSm
                            textFormat: Text.StyledText
                            wrapMode: Text.WordWrap
                            maximumLineCount: 6
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                            onLinkActivated: link => Qt.openUrlExternally(link)
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 2
                    spacing: 6
                    visible: item.modelData.notif && item.modelData.notif.actions.length > 0

                    Repeater {
                        model: item.modelData.notif ? item.modelData.notif.actions : []

                        Rectangle {
                            id: act
                            required property var modelData

                            implicitWidth: actText.implicitWidth + 18
                            implicitHeight: 22
                            radius: Theme.radiusSm
                            color: actMa.containsMouse ? Theme.a(Theme.acc, 0.15) : "transparent"
                            border.width: 1
                            border.color: actMa.containsMouse ? Theme.a(Theme.acc, 0.5) : Theme.bdr

                            Text {
                                id: actText
                                anchors.centerIn: parent
                                text: act.modelData.text
                                color: actMa.containsMouse ? Theme.acc : Theme.fgDim
                                font.family: Theme.font
                                font.pixelSize: Theme.fsXs
                            }

                            MouseArea {
                                id: actMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: act.modelData.invoke()
                            }
                        }
                    }
                }
            }
        }
    }
}
