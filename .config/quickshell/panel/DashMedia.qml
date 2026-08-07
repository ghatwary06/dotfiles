import Quickshell.Services.Mpris
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects

// Now playing: album art, track info, a scrubbable position bar and transport.
WCard {
    id: card
    title: "NOW PLAYING"
    hint: Media.has ? Media.identity : ""

    // While dragging we show the drag position rather than the player's, so the
    // handle doesn't snap back on every poll before the seek lands.
    property bool scrubbing: false
    property real scrubValue: 0
    readonly property real shownProgress: scrubbing ? scrubValue : Media.progress
    readonly property real shownPosition: scrubbing ? scrubValue * Media.length : Media.position

    // ------------------------------------------------------------ empty -- //
    Item {
        Layout.fillWidth: true
        implicitHeight: 64
        visible: !Media.has

        ColumnLayout {
            anchors.centerIn: parent
            spacing: 4

            Text {
                text: "󰝛"
                color: Theme.fgFaint
                font.family: Theme.font
                font.pixelSize: 22
                Layout.alignment: Qt.AlignHCenter
            }

            Text {
                text: "nothing playing"
                color: Theme.fgFaint
                font.family: Theme.font
                font.pixelSize: Theme.fsSm
                Layout.alignment: Qt.AlignHCenter
            }
        }
    }

    // ------------------------------------------------------------ track -- //
    RowLayout {
        Layout.fillWidth: true
        spacing: 14
        visible: Media.has

        // -- album art ------------------------------------------------------
        Rectangle {
            Layout.preferredWidth: 92
            Layout.preferredHeight: 92
            Layout.alignment: Qt.AlignTop
            radius: Theme.radius
            color: Theme.bg2
            border.width: 1
            border.color: Theme.bdr

            Text {
                anchors.centerIn: parent
                visible: art.status !== Image.Ready
                text: "󰝚"
                color: Theme.fgFaint
                font.family: Theme.font
                font.pixelSize: 26
            }

            Image {
                id: art
                anchors.fill: parent
                anchors.margins: 1
                source: Media.art
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: true
                visible: false          // drawn through the mask below
                sourceSize.width: 184   // 2x for HiDPI-ish crispness
                sourceSize.height: 184
            }

            // Rectangular clipping can't round corners, so mask the image.
            MultiEffect {
                anchors.fill: art
                source: art
                visible: art.status === Image.Ready
                maskEnabled: true
                maskSource: mask
                maskThresholdMin: 0.5
                maskSpreadAtMin: 1.0
            }

            Item {
                id: mask
                anchors.fill: art
                layer.enabled: true
                visible: false

                Rectangle {
                    anchors.fill: parent
                    radius: Theme.radius - 1
                    color: "black"
                }
            }
        }

        // -- text + transport ----------------------------------------------
        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignTop
            spacing: 3

            Text {
                text: Media.title || "unknown track"
                color: Theme.fg
                font.family: Theme.font
                font.pixelSize: Theme.fsMd
                font.weight: Font.DemiBold
                elide: Text.ElideRight
                Layout.fillWidth: true
            }

            Text {
                text: Media.artist
                visible: text.length > 0
                color: Theme.acc
                font.family: Theme.font
                font.pixelSize: Theme.fsSm
                elide: Text.ElideRight
                Layout.fillWidth: true
            }

            Text {
                text: Media.album
                visible: text.length > 0
                color: Theme.fgDim
                font.family: Theme.font
                font.pixelSize: Theme.fsXs
                elide: Text.ElideRight
                Layout.fillWidth: true
            }

            Item {
                Layout.fillHeight: true
                Layout.minimumHeight: 4
            }

            // -- transport --------------------------------------------------
            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 2
                spacing: 4

                Repeater {
                    model: [
                        {
                            g: "󰒮",
                            act: "prev",
                            size: 17,
                            on: Media.has && Media.player.canGoPrevious
                        },
                        {
                            g: Media.playing ? "󰏤" : "󰐊",
                            act: "toggle",
                            size: 22,
                            on: Media.has && Media.player.canTogglePlaying
                        },
                        {
                            g: "󰒭",
                            act: "next",
                            size: 17,
                            on: Media.has && Media.player.canGoNext
                        }
                    ]

                    Rectangle {
                        id: btn
                        required property var modelData

                        implicitWidth: modelData.act === "toggle" ? 34 : 28
                        implicitHeight: modelData.act === "toggle" ? 34 : 28
                        radius: Theme.radiusSm
                        color: !modelData.on ? "transparent" : (bma.containsMouse ? Theme.a(Theme.acc, 0.16) : Theme.a(Theme.bg2, 0.8))
                        border.width: 1
                        border.color: !modelData.on ? "transparent" : (bma.containsMouse ? Theme.a(Theme.acc, 0.5) : Theme.bdr)

                        Behavior on color {
                            ColorAnimation {
                                duration: Theme.animFast
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            text: btn.modelData.g
                            color: !btn.modelData.on ? Theme.fgFaint : (bma.containsMouse ? Theme.acc : Theme.fg)
                            font.family: Theme.font
                            font.pixelSize: btn.modelData.size
                        }

                        MouseArea {
                            id: bma
                            anchors.fill: parent
                            enabled: btn.modelData.on
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (btn.modelData.act === "prev")
                                    Media.previous();
                                else if (btn.modelData.act === "next")
                                    Media.next();
                                else
                                    Media.toggle();
                            }
                        }
                    }
                }

                Item {
                    Layout.fillWidth: true
                }

                Text {
                    text: Media.seekable ? "" : "not seekable"
                    color: Theme.fgFaint
                    font.family: Theme.font
                    font.pixelSize: Theme.fsXs
                }
            }
        }
    }

    // ----------------------------------------------------------- seek bar -- //
    ColumnLayout {
        Layout.fillWidth: true
        Layout.topMargin: 4
        spacing: 4
        visible: Media.has && Media.length > 0

        // Generous 16px hit area around a 4px visual bar — a 4px target is
        // miserable to hit with a mouse.
        Item {
            id: track
            Layout.fillWidth: true
            implicitHeight: 16

            Rectangle {
                id: rail
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                height: 4
                radius: 2
                color: Theme.bg2

                Rectangle {
                    width: parent.width * card.shownProgress
                    height: parent.height
                    radius: parent.radius
                    color: Theme.acc

                    Behavior on width {
                        enabled: !card.scrubbing
                        NumberAnimation {
                            duration: 400
                            easing.type: Easing.Linear
                        }
                    }
                }
            }

            Rectangle {
                id: handle
                width: 10
                height: 10
                radius: 5
                color: Theme.acc
                border.width: 2
                border.color: Theme.bg0
                anchors.verticalCenter: parent.verticalCenter
                x: Math.max(0, Math.min(track.width - width, rail.width * card.shownProgress - width / 2))
                opacity: seekMa.containsMouse || card.scrubbing ? 1 : 0
                scale: card.scrubbing ? 1.25 : 1

                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.animFast
                    }
                }
                Behavior on scale {
                    NumberAnimation {
                        duration: Theme.animFast
                    }
                }
            }

            MouseArea {
                id: seekMa
                anchors.fill: parent
                enabled: Media.seekable
                hoverEnabled: true
                cursorShape: Media.seekable ? Qt.PointingHandCursor : Qt.ArrowCursor
                preventStealing: true

                function fractionAt(mx) {
                    return Math.max(0, Math.min(1, mx / track.width));
                }

                onPressed: function (mouse) {
                    card.scrubValue = fractionAt(mouse.x);
                    card.scrubbing = true;
                }
                onPositionChanged: function (mouse) {
                    if (card.scrubbing)
                        card.scrubValue = fractionAt(mouse.x);
                }
                onReleased: function (mouse) {
                    const f = fractionAt(mouse.x);
                    Media.seekFraction(f);
                    // Hold the scrub value briefly: players report the old
                    // position for a tick or two after a seek.
                    settle.restart();
                }
                onCanceled: card.scrubbing = false
            }

            Timer {
                id: settle
                interval: 350
                onTriggered: card.scrubbing = false
            }
        }

        RowLayout {
            Layout.fillWidth: true

            Text {
                text: Media.fmt(card.shownPosition)
                color: card.scrubbing ? Theme.acc : Theme.fgDim
                font.family: Theme.font
                font.pixelSize: Theme.fsXs
            }

            Item {
                Layout.fillWidth: true
            }

            Text {
                text: Media.fmt(Media.length)
                color: Theme.fgDim
                font.family: Theme.font
                font.pixelSize: Theme.fsXs
            }
        }
    }

    // ------------------------------------------------------ audio output -- //
    // Sits with the media controls on purpose: "where is this playing" is a
    // question you ask WHILE looking at what is playing, and the alternative
    // was launching pavucontrol every time.
    Rectangle {
        Layout.fillWidth: true
        Layout.topMargin: 6
        implicitHeight: 1
        color: Theme.bdr
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 4

        Text {
            text: "󰕾"
            color: Theme.fgDim
            font.family: Theme.font
            font.pixelSize: Theme.fsSm
        }

        Repeater {
            model: Audio.sinks

            Rectangle {
                id: sinkChip
                required property var modelData
                readonly property bool on: Audio.current && Audio.current.id === modelData.id

                Layout.fillWidth: true
                implicitHeight: 22
                radius: Theme.radiusSm
                color: on ? Theme.a(Theme.acc, 0.18) : (sma.containsMouse ? Theme.a(Theme.chipHi, 0.8) : Theme.a(Theme.bg2, 0.45))
                border.width: 1
                border.color: on ? Theme.a(Theme.acc, 0.6) : Theme.bdr

                Behavior on color {
                    ColorAnimation {
                        duration: Theme.animFast
                    }
                }

                Row {
                    anchors.centerIn: parent
                    spacing: 4

                    Text {
                        text: Audio.icon(sinkChip.modelData)
                        color: sinkChip.on ? Theme.acc : Theme.fgDim
                        font.family: Theme.font
                        font.pixelSize: Theme.fsSm
                    }

                    Text {
                        text: Audio.label(sinkChip.modelData)
                        color: sinkChip.on ? Theme.acc : Theme.fgDim
                        font.family: Theme.font
                        font.pixelSize: Theme.fsXs
                        font.weight: sinkChip.on ? Font.DemiBold : Font.Normal
                        elide: Text.ElideRight
                        width: Math.min(implicitWidth, sinkChip.width - 26)
                    }
                }

                MouseArea {
                    id: sma
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Audio.setSink(sinkChip.modelData)
                }
            }
        }
    }
}
