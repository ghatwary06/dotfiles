import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts

// Slide-out control surface on the right edge.
// Blur comes from Hyprland (layerrule on the "qs-sidepanel" namespace); the
// window itself is transparent and only the inner card is painted.
PanelWindow {
    id: win

    property bool open: false
    property string tab: "system"

    function show(which) {
        if (which && which.length > 0)
            tab = which;
        open = true;
    }

    function toggle(which) {
        // Clicking the same entry point twice closes; a different one switches.
        if (open && (!which || which === tab))
            open = false;
        else
            show(which);
    }

    // Animated 0 → 1; drives both the slide and the fade.
    property real reveal: open ? 1 : 0
    Behavior on reveal {
        NumberAnimation {
            duration: Theme.animSlide
            easing.type: Easing.OutCubic
        }
    }

    anchors {
        top: true
        right: true
        bottom: true
    }
    margins {
        top: 44          // clears waybar (32px bar + 6px margin + gap)
        right: 10
        bottom: 10
    }

    implicitWidth: Theme.panelWidth
    exclusiveZone: 0
    color: "transparent"

    // Kept mapped through the closing animation, then fully unmapped so it
    // never eats clicks while hidden.
    visible: reveal > 0.001

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "qs-sidepanel"
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    // The panel is STICKY: it stays up until you deliberately dismiss it, via
    // the ✕ button, Escape, or the same SUPER+A / bar entry point that opened
    // it. Clicking away, focusing another window, or typing elsewhere all leave
    // it alone.
    //
    // This used to be a HyprlandFocusGrab with `onCleared: win.open = false`,
    // which closed the panel on the first click ANYWHERE else — so it was
    // impossible to read it while doing something in another window, and it
    // vanished the moment you reached for a screenshot.
    //
    // keyboardFocus stays OnDemand rather than Exclusive, so the process filter
    // still takes keystrokes when clicked, but the panel never steals the
    // keyboard from whatever you are actually working in.

    Item {
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: win.open = false

        Rectangle {
            id: card

            // Anchored, so the slide is done with a transform rather than x.
            anchors.fill: parent
            opacity: win.reveal
            transform: Translate {
                x: (1 - win.reveal) * card.width
            }

            radius: Theme.radius
            color: Theme.panelBg
            border.width: 1
            border.color: Theme.bdr

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Theme.pad
                spacing: Theme.gap

                // ------------------------------------------------- header --
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.gap

                    Text {
                        text: "▸"
                        color: Theme.acc
                        font.family: Theme.font
                        font.pixelSize: Theme.fsMd
                    }

                    Text {
                        text: (Quickshell.env("USER") || "user") + " ~ control"
                        color: Theme.fg
                        font.family: Theme.font
                        font.pixelSize: Theme.fsMd
                        font.weight: Font.DemiBold
                    }

                    Item {
                        Layout.fillWidth: true
                    }

                    Text {
                        text: Sys.uptime
                        color: Theme.fgFaint
                        font.family: Theme.font
                        font.pixelSize: Theme.fsXs
                    }

                    Text {
                        text: "󰅖"
                        color: closeMa.containsMouse ? Theme.crit : Theme.fgDim
                        font.family: Theme.font
                        font.pixelSize: Theme.fsMd

                        MouseArea {
                            id: closeMa
                            anchors.fill: parent
                            anchors.margins: -5
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: win.open = false
                        }
                    }
                }

                // ------------------------------------------------- tabbar --
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    Repeater {
                        model: [
                            {
                                id: "system",
                                icon: "󰍛",
                                label: "SYSTEM"
                            },
                            {
                                id: "notifications",
                                icon: "󰂚",
                                label: "NOTIFS"
                            },
                            {
                                id: "network",
                                icon: "󰀂",
                                label: "NETWORK"
                            },
                            {
                                id: "chat",
                                icon: "󰭹",
                                label: "CHAT"
                            }
                        ]

                        Rectangle {
                            id: tabBtn
                            required property var modelData
                            readonly property bool sel: win.tab === modelData.id

                            Layout.fillWidth: true
                            implicitHeight: 26
                            radius: Theme.radiusSm
                            color: sel ? Theme.a(Theme.acc, 0.12) : (tabMa.containsMouse ? Theme.a(Theme.bg2, 0.7) : "transparent")
                            border.width: 1
                            border.color: sel ? Theme.a(Theme.acc, 0.45) : Theme.a(Theme.bdr, 0.7)

                            Behavior on color {
                                ColorAnimation {
                                    duration: Theme.animFast
                                }
                            }

                            RowLayout {
                                anchors.centerIn: parent
                                spacing: 6

                                Text {
                                    text: tabBtn.modelData.icon
                                    color: tabBtn.sel ? Theme.acc : Theme.fgDim
                                    font.family: Theme.font
                                    font.pixelSize: Theme.fsMd
                                }

                                Text {
                                    text: tabBtn.modelData.label
                                    color: tabBtn.sel ? Theme.acc : Theme.fgDim
                                    font.family: Theme.font
                                    font.pixelSize: Theme.fsXs
                                    font.weight: Font.DemiBold
                                    font.letterSpacing: 0.8
                                }

                                // Unread badge on the notifications tab.
                                Rectangle {
                                    visible: tabBtn.modelData.id === "notifications" && Notifs.count > 0
                                    implicitWidth: 16
                                    implicitHeight: 14
                                    radius: 3
                                    color: Theme.a(Theme.acc, 0.85)

                                    Text {
                                        anchors.centerIn: parent
                                        text: Notifs.count > 9 ? "9+" : Notifs.count
                                        color: Theme.bg0
                                        font.family: Theme.font
                                        font.pixelSize: 9
                                        font.weight: Font.Bold
                                    }
                                }
                            }

                            MouseArea {
                                id: tabMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: win.tab = tabBtn.modelData.id
                            }
                        }
                    }
                }

                // ------------------------------------------------ content --
                Flickable {
                    id: flick
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    contentWidth: width
                    contentHeight: pageLoader.height
                    boundsBehavior: Flickable.StopAtBounds
                    flickDeceleration: 6000

                    Loader {
                        id: pageLoader
                        width: flick.width
                        // Chat fills the panel: it is a workspace, not a readout,
                        // and a transcript squeezed into ~360px wasted most of a
                        // 1000px-tall panel. The other tabs stay content-sized so
                        // they do not stretch into empty space.
                        height: win.tab === "chat" ? flick.height : (item ? item.implicitHeight : 0)
                        sourceComponent: win.tab === "notifications" ? cNotifs : win.tab === "network" ? cNetwork : win.tab === "chat" ? cChat : cSystem
                    }
                }

                // ------------------------------------- pinned quick toggles --
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 1
                    color: Theme.bdr
                }

                // Brightness sits with the toggles, above them: both are things
                // you reach for constantly, and neither should depend on which
                // tab happens to be open.
                SecBrightness {
                    Layout.fillWidth: true
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 1
                    color: Theme.bdr
                }

                SecToggles {
                    Layout.fillWidth: true
                }
            }
        }
    }

    Component {
        id: cSystem
        SecSystem {}
    }
    Component {
        id: cNotifs
        SecNotifs {}
    }
    Component {
        id: cNetwork
        SecNetwork {}
    }
    Component {
        id: cChat
        SecChat {}
    }

    // Telemetry only polls while the panel is actually on screen.
    onVisibleChanged: {
        if (visible)
            Sys.subscribe();
        else
            Sys.unsubscribe();
    }
}
