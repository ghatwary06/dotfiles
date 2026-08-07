import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts

// Centre dashboard: clock, weather, calendar and a full media player with
// scrubbable position. Opened from the weather or clock in the bar, or SUPER+G.
PanelWindow {
    id: win

    property bool open: false

    function show() {
        open = true;
    }

    function toggle() {
        open = !open;
    }

    property real reveal: open ? 1 : 0
    Behavior on reveal {
        NumberAnimation {
            duration: Theme.animSlide
            easing.type: Easing.OutCubic
        }
    }

    // Anchored to the TOP EDGE ONLY. With neither left nor right anchored,
    // layer-shell centres the surface on that axis for us — and, critically,
    // the window is then only as wide as the card. Anchoring left+right would
    // stretch it across the screen and the transparent margins either side
    // would silently swallow clicks meant for the windows underneath.
    anchors.top: true
    margins.top: 44

    implicitWidth: card.width
    implicitHeight: Math.max(1, card.implicitHeight)
    exclusiveZone: 0
    color: "transparent"
    visible: reveal > 0.001

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "qs-dash"
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    HyprlandFocusGrab {
        windows: [win]
        active: win.open
        onCleared: win.open = false
    }

    Item {
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: win.open = false

        Rectangle {
            id: card

            width: 620
            implicitHeight: body.implicitHeight + Theme.pad * 2

            radius: Theme.radius
            color: Theme.panelBg
            border.width: 1
            border.color: Theme.bdr

            opacity: win.reveal
            transform: Translate {
                y: (1 - win.reveal) * -18
            }

            ColumnLayout {
                id: body
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Theme.pad
                spacing: Theme.gap

                DashClock {}

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.gap
                    Layout.alignment: Qt.AlignTop

                    DashCalendar {
                        Layout.preferredWidth: 1
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignTop
                    }

                    DashWeather {
                        Layout.preferredWidth: 1
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignTop
                    }
                }

                DashMedia {}
            }
        }
    }

    // MPRIS position isn't push-based; only poll it while we're on screen.
    onVisibleChanged: {
        if (visible) {
            Media.watch();
            Weather.refresh();
        } else {
            Media.unwatch();
        }
    }
}
