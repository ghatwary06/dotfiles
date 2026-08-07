import QtQuick
import QtQuick.Layouts

// Chat surface for the side panel.
//
// Backed by the `claude` CLI through Chat.qml — no API key, it reuses the
// Claude Code login on this machine. This is a FULL agent: it can read files,
// run commands and edit things, exactly like the terminal. chat.sh runs it in
// --permission-mode auto (the classifier refuses dangerous actions by itself,
// since a panel cannot draw an approval prompt) with MCP connectors off.
ColumnLayout {
    id: page
    spacing: Theme.gap

    // The Loader in SidePanel gives the chat tab the panel's full height, so
    // the card and the transcript inside it stretch to fill rather than sitting
    // in a fixed 360px box with dead space underneath.
    height: parent ? parent.height : implicitHeight

    // The panel is 400px wide; a wall of full-width text is unreadable, so
    // bubbles cap short of the edge and the roles sit on opposite sides.
    readonly property int bubbleMax: Math.round(width * 0.86)

    Connections {
        target: Chat
        function onScrollWanted() {
            scrollTimer.restart();
        }
    }

    // Coalesce: token deltas fire far faster than it is worth re-measuring the
    // content height.
    Timer {
        id: scrollTimer
        interval: 60
        onTriggered: log.contentY = Math.max(0, log.contentHeight - log.height)
    }

    WCard {
        Layout.fillHeight: true
        title: "CHAT"
        hint: Chat.busy ? "thinking…" : (Chat.messages.length > 0 ? (Chat.messages.length + " msgs") : "claude")

        // ------------------------------------------------------ transcript -- //
        Flickable {
            id: log
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: 120
            contentWidth: width
            contentHeight: col.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            flickDeceleration: 6000

            ColumnLayout {
                id: col
                width: log.width
                spacing: 6

                // empty state
                Text {
                    Layout.fillWidth: true
                    Layout.topMargin: 12
                    Layout.bottomMargin: 12
                    visible: Chat.messages.length === 0 && !Chat.busy && Chat.error.length === 0
                    horizontalAlignment: Text.AlignHCenter
                    text: "ask claude anything\nfull tools · runs in ~"
                    color: Theme.fgFaint
                    font.family: Theme.font
                    font.pixelSize: Theme.fsXs
                    lineHeight: 1.4
                }

                Repeater {
                    model: Chat.messages

                    RowLayout {
                        id: turn
                        required property var modelData
                        readonly property bool mine: modelData.role === "user"
                        readonly property bool isTool: modelData.role === "tool"

                        Layout.fillWidth: true
                        spacing: 0

                        // Tool call — a compact line, not a bubble. It is the
                        // agent showing its work, so it should read as a log
                        // entry and never compete with the actual answer.
                        Rectangle {
                            visible: turn.isTool
                            Layout.fillWidth: true
                            implicitHeight: turn.isTool ? toolRow.implicitHeight + 8 : 0
                            radius: 3
                            color: Theme.a(Theme.bg2, 0.4)
                            border.width: 1
                            border.color: Theme.a(Theme.bdr, 0.8)

                            RowLayout {
                                id: toolRow
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.margins: 4
                                spacing: 5

                                Text {
                                    text: "󰅱"
                                    color: Theme.acc
                                    font.family: Theme.font
                                    font.pixelSize: Theme.fsXs
                                }

                                Text {
                                    text: turn.modelData.name || "tool"
                                    color: Theme.acc
                                    font.family: Theme.font
                                    font.pixelSize: Theme.fsXs
                                    font.weight: Font.DemiBold
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: turn.modelData.text
                                    color: Theme.fgDim
                                    font.family: Theme.font
                                    font.pixelSize: Theme.fsXs
                                    elide: Text.ElideRight
                                    maximumLineCount: 2
                                    wrapMode: Text.WrapAnywhere
                                }
                            }
                        }

                        Item {
                            Layout.fillWidth: turn.mine
                            visible: turn.mine && !turn.isTool
                        }

                        Rectangle {
                            visible: !turn.isTool
                            Layout.maximumWidth: page.bubbleMax
                            Layout.preferredWidth: Math.min(page.bubbleMax, body.implicitWidth + 16)
                            implicitHeight: body.implicitHeight + 12
                            radius: Theme.radiusSm
                            color: turn.mine ? Theme.a(Theme.acc, 0.16) : Theme.a(Theme.bg2, 0.55)
                            border.width: 1
                            border.color: turn.mine ? Theme.a(Theme.acc, 0.35) : Theme.bdr

                            Text {
                                id: body
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.margins: 8
                                text: turn.modelData.text
                                color: Theme.fg
                                font.family: Theme.font
                                font.pixelSize: Theme.fsSm
                                wrapMode: Text.Wrap
                                // Markdown so code fences, bold and lists render
                                // as themselves instead of as literal asterisks.
                                textFormat: Text.MarkdownText
                                onLinkActivated: l => Qt.openUrlExternally(l)
                            }

                            MouseArea {
                                anchors.fill: parent
                                acceptedButtons: Qt.RightButton
                                onClicked: {
                                    Sys.copyText(turn.modelData.text);
                                    copied.restart();
                                }
                            }
                        }

                        Item {
                            Layout.fillWidth: !turn.mine
                            visible: !turn.mine && !turn.isTool
                        }
                    }
                }

                // in-flight reply
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    visible: Chat.busy

                    Rectangle {
                        Layout.maximumWidth: page.bubbleMax
                        Layout.preferredWidth: Math.min(page.bubbleMax, live.implicitWidth + 16)
                        implicitHeight: live.implicitHeight + 12
                        radius: Theme.radiusSm
                        color: Theme.a(Theme.bg2, 0.55)
                        border.width: 1
                        border.color: Theme.a(Theme.acc, 0.3)

                        Text {
                            id: live
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: 8
                            text: Chat.streamText.length > 0 ? Chat.streamText : "…"
                            color: Chat.streamText.length > 0 ? Theme.fg : Theme.fgFaint
                            font.family: Theme.font
                            font.pixelSize: Theme.fsSm
                            wrapMode: Text.Wrap
                            textFormat: Text.MarkdownText

                            // Pulse only while waiting for the first token, so a
                            // streaming answer is not distractingly animated.
                            SequentialAnimation on opacity {
                                running: Chat.busy && Chat.streamText.length === 0
                                loops: Animation.Infinite
                                NumberAnimation {
                                    to: 0.35
                                    duration: 600
                                }
                                NumberAnimation {
                                    to: 1.0
                                    duration: 600
                                }
                            }
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                    }
                }

                // error
                Rectangle {
                    Layout.fillWidth: true
                    visible: Chat.error.length > 0
                    implicitHeight: errTxt.implicitHeight + 12
                    radius: Theme.radiusSm
                    color: Theme.a(Theme.crit, 0.12)
                    border.width: 1
                    border.color: Theme.a(Theme.crit, 0.4)

                    Text {
                        id: errTxt
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 6
                        text: Chat.error
                        color: Theme.crit
                        font.family: Theme.font
                        font.pixelSize: Theme.fsXs
                        wrapMode: Text.Wrap
                    }
                }
            }
        }

        // --------------------------------------------------------- composer -- //
        RowLayout {
            Layout.fillWidth: true
            spacing: 4

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: Math.min(90, Math.max(26, input.implicitHeight + 10))
                radius: Theme.radiusSm
                color: Theme.a(Theme.bg2, input.activeFocus ? 0.8 : 0.45)
                border.width: 1
                border.color: input.activeFocus ? Theme.a(Theme.acc, 0.55) : Theme.bdr

                TextEdit {
                    id: input
                    anchors.fill: parent
                    anchors.margins: 6
                    color: Theme.fg
                    font.family: Theme.font
                    font.pixelSize: Theme.fsSm
                    selectByMouse: true
                    selectionColor: Theme.a(Theme.acc, 0.35)
                    wrapMode: TextEdit.Wrap
                    textFormat: TextEdit.PlainText
                    clip: true

                    // Enter sends; Shift+Enter is a newline. Handled in Keys
                    // rather than onAccepted because TextEdit is multi-line and
                    // has no accepted signal.
                    Keys.onPressed: function (e) {
                        if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) {
                            if (e.modifiers & Qt.ShiftModifier)
                                return;              // let the newline through
                            e.accepted = true;
                            if (Chat.send(input.text))
                                input.text = "";
                        } else if (e.key === Qt.Key_Escape) {
                            if (input.text.length > 0) {
                                input.text = "";
                                e.accepted = true;
                            }
                        }
                    }

                    Text {
                        anchors.left: parent.left
                        anchors.top: parent.top
                        text: "message claude · enter to send"
                        color: Theme.fgFaint
                        font.family: Theme.font
                        font.pixelSize: Theme.fsSm
                        visible: input.text.length === 0 && !input.activeFocus
                    }
                }
            }

            // send / stop — one button, because they are never both useful
            Rectangle {
                implicitWidth: 28
                implicitHeight: 26
                radius: Theme.radiusSm
                readonly property bool stopMode: Chat.busy
                readonly property bool armed: stopMode || input.text.trim().length > 0
                color: sendMa.containsMouse && armed ? Theme.a(stopMode ? Theme.crit : Theme.acc, 0.2) : Theme.a(Theme.bg2, 0.5)
                border.width: 1
                border.color: armed ? Theme.a(stopMode ? Theme.crit : Theme.acc, 0.6) : Theme.bdr

                Text {
                    anchors.centerIn: parent
                    text: parent.stopMode ? "󰓛" : "󰊵"
                    color: parent.armed ? (parent.stopMode ? Theme.crit : Theme.acc) : Theme.fgFaint
                    font.family: Theme.font
                    font.pixelSize: Theme.fsSm
                }

                MouseArea {
                    id: sendMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: parent.armed ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: {
                        if (Chat.busy) {
                            Chat.stop();
                        } else if (Chat.send(input.text)) {
                            input.text = "";
                        }
                    }
                }
            }

            // New conversation — drops the session id, so the next message
            // starts with no memory of this one. Labelled rather than a bare
            // glyph: the icon-only version was already there and went unnoticed.
            Rectangle {
                implicitWidth: newRow.implicitWidth + 14
                implicitHeight: 26
                radius: Theme.radiusSm
                color: newMa.containsMouse ? Theme.a(Theme.acc, 0.16) : Theme.a(Theme.bg2, 0.5)
                border.width: 1
                border.color: newMa.containsMouse ? Theme.a(Theme.acc, 0.5) : Theme.bdr

                Row {
                    id: newRow
                    anchors.centerIn: parent
                    spacing: 4

                    Text {
                        text: "󰑐"
                        color: newMa.containsMouse ? Theme.acc : Theme.fgDim
                        font.family: Theme.font
                        font.pixelSize: Theme.fsSm
                    }

                    Text {
                        text: "NEW"
                        color: newMa.containsMouse ? Theme.acc : Theme.fgDim
                        font.family: Theme.font
                        font.pixelSize: Theme.fsXs
                        font.weight: Font.DemiBold
                        font.letterSpacing: 0.6
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                MouseArea {
                    id: newMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        Chat.clear();
                        input.text = "";
                    }
                }
            }
        }

        Text {
            Layout.fillWidth: true
            text: copied.running ? "copied to clipboard" : (Chat.sessionId.length > 0 ? "thread active · full tools · shift+enter = newline" : "full tools · runs in ~ · shift+enter = newline")
            color: copied.running ? Theme.ok : Theme.fgFaint
            font.family: Theme.font
            font.pixelSize: Theme.fsXs
            elide: Text.ElideRight
        }

        Timer {
            id: copied
            interval: 1800
        }
    }
}
