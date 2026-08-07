import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts

// ===========================================================================
//  Left bar cluster: workspace pills + running-apps taskbar.
//
//  WHY THIS LIVES HERE AND NOT IN WAYBAR
//  The taskbar had to be Quickshell-native, and it had to sit flush against
//  the workspace pills. A second surface cannot know how wide waybar's
//  workspace module is, and that width changes as windows come and go — so
//  the pills came across too. waybar keeps the os button, centre and right.
//
//  The strip is a transparent overlay sitting inside waybar's own slab, which
//  is what keeps it reading as ONE bar rather than two docked widgets.
//  It is on the Overlay layer (the only way to guarantee it draws above
//  waybar's "top" layer, since same-layer stacking order is not controllable)
//  and therefore hides itself when a window goes fullscreen — Overlay would
//  otherwise float over a fullscreen game or video.
// ===========================================================================
Variants {
    // One strip per monitor.
    model: Quickshell.screens

    PanelWindow {
        id: strip
        required property var modelData

        screen: modelData
        readonly property string monName: modelData ? modelData.name : ""

        // Which workspaces belong to which output. Mirrors the `workspace = N,
        // monitor:...` rules in hyprland.conf; kept explicit so empty
        // workspaces still show a pill (Hyprland only reports live ones).
        readonly property var persistent: ({
                "HDMI-A-1": [1, 2, 3, 4, 5],
                "eDP-1": [6, 7, 8, 9, 10]
            })

        readonly property var wsIds: persistent[monName] !== undefined ? persistent[monName] : []

        // -- live Hyprland state ------------------------------------------------
        readonly property var liveWorkspaces: Hyprland.workspaces ? Hyprland.workspaces.values : []
        readonly property var liveToplevels: Hyprland.toplevels ? Hyprland.toplevels.values : []

        function wsFor(id) {
            return liveWorkspaces.find(w => w.id === id) ?? null;
        }

        // Windows living on this monitor, ordered by workspace so the strip
        // doesn't reshuffle every time something is focused.
        readonly property var myToplevels: {
            const out = liveToplevels.filter(function (t) {
                if (!t.monitor || t.monitor.name !== strip.monName)
                    return false;
                // Special workspaces have negative ids. The preloaded LibreWolf
                // parked on `special:preload` is deliberately hidden, and the
                // scratchpad shouldn't clutter the taskbar either.
                if (t.workspace && t.workspace.id < 0)
                    return false;
                return true;
            });
            out.sort(function (a, b) {
                const aw = a.workspace ? a.workspace.id : 0;
                const bw = b.workspace ? b.workspace.id : 0;
                if (aw !== bw)
                    return aw - bw;
                return a.address < b.address ? -1 : 1;
            });
            return out;
        }

        // Overlay must not cover a fullscreen window.
        readonly property bool anyFullscreen: {
            for (const w of liveWorkspaces) {
                if (w.monitor && w.monitor.name === strip.monName && w.active && w.hasFullscreen)
                    return true;
            }
            return false;
        }

        // -- geometry -----------------------------------------------------------
        // Sits inside waybar's slab, immediately right of the os button.
        //   10  waybar margin-left
        //  + 1  waybar border
        //  + 50 os button (margin 5 + pad 13 + 16 + pad 13 + margin 3)
        // The os button is fixed-width, so this offset is stable — verified
        // against a screenshot rather than assumed.
        anchors {
            top: true
            left: true
        }
        margins {
            top: 6      // waybar margin-top
            left: 61
        }

        // Content-sized so the surface never covers bar area it isn't using —
        // a full-width transparent strip would silently eat clicks. Capped so
        // an unusually large window count can't run into waybar's centre chip;
        // beyond the cap the tail of the taskbar clips rather than overlapping.
        implicitWidth: Math.max(1, Math.min(row.implicitWidth, 620))
        implicitHeight: 34  // waybar height, so pills line up with the chips

        // Ignore, not 0. `exclusiveZone: 0` still RESPECTS other surfaces'
        // exclusive zones, so waybar's 40px reservation pushed this strip to
        // y=46 — below the bar instead of inside it. Ignore opts out entirely
        // and lets margins.top place it absolutely.
        exclusionMode: ExclusionMode.Ignore
        exclusiveZone: 0

        color: "transparent"
        visible: !anyFullscreen

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "qs-bar"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        // Belt-and-braces: pull fresh IPC detail when the window set changes,
        // so workspace membership and titles settle quickly even though the
        // icon itself no longer waits on this.
        Connections {
            target: Hyprland

            function onRawEvent(event) {
                switch (event.name) {
                case "openwindow":
                case "closewindow":
                case "movewindow":
                case "movewindowv2":
                case "changefloatingmode":
                    Hyprland.refreshToplevels();
                    break;
                }
            }
        }

        RowLayout {
            id: row
            anchors.fill: parent
            spacing: 0
            clip: true

            // ---------------------------------------------------- workspaces --
            RowLayout {
                spacing: 4
                Layout.alignment: Qt.AlignVCenter

                Repeater {
                    model: strip.wsIds

                    Rectangle {
                        id: pill
                        required property var modelData

                        readonly property var ws: strip.wsFor(modelData)
                        readonly property bool isActive: ws ? ws.active : false
                        readonly property bool isUrgent: ws ? ws.urgent : false
                        readonly property int winCount: ws && ws.toplevels ? ws.toplevels.values.length : 0
                        readonly property bool populated: winCount > 0

                        implicitWidth: 26
                        implicitHeight: 24
                        Layout.alignment: Qt.AlignVCenter
                        radius: Theme.radiusSm

                        color: isUrgent ? Theme.a(Theme.crit, 0.16) : isActive ? Theme.a(Theme.acc, 0.14) : populated ? Theme.chip : "transparent"

                        border.width: 1
                        border.color: isUrgent ? Theme.a(Theme.crit, 0.55) : isActive ? Theme.a(Theme.acc, 0.5) : populated ? Theme.bdrHi : "transparent"

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

                        Text {
                            anchors.centerIn: parent
                            text: pill.modelData
                            color: pill.isUrgent ? Theme.crit : pill.isActive ? Theme.acc : pill.populated ? Theme.fg : Theme.fgFaint
                            font.family: Theme.font
                            font.pixelSize: Theme.fsSm
                            font.weight: pill.isActive ? Font.Bold : Font.Medium
                        }

                        // Accent underline on the active workspace.
                        Rectangle {
                            anchors.bottom: parent.bottom
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: pill.isActive ? parent.width - 8 : 0
                            height: 2
                            radius: 1
                            color: Theme.acc

                            Behavior on width {
                                NumberAnimation {
                                    duration: Theme.animFast
                                    easing.type: Easing.OutCubic
                                }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            hoverEnabled: true
                            onEntered: pill.scale = 1.06
                            onExited: pill.scale = 1.0
                            // Hyprland 0.56 Lua config: dispatch takes Lua, not
                            // dispatcher names. "workspace N" silently no-ops.
                            onClicked: Hyprland.dispatch("hl.dsp.focus({ workspace = " + pill.modelData + " })")
                        }

                        Behavior on scale {
                            NumberAnimation {
                                duration: Theme.animFast
                            }
                        }
                    }
                }
            }

            // ------------------------------------------------------ separator --
            Rectangle {
                Layout.leftMargin: 8
                Layout.rightMargin: 8
                Layout.alignment: Qt.AlignVCenter
                implicitWidth: 1
                implicitHeight: 16
                color: Theme.bdrHi
                visible: strip.myToplevels.length > 0
            }

            // -------------------------------------------------------- taskbar --
            RowLayout {
                spacing: 2
                Layout.alignment: Qt.AlignVCenter

                Repeater {
                    model: strip.myToplevels

                    Item {
                        id: task
                        required property var modelData

                        // appId comes straight off the wayland handle and is
                        // populated the moment the window maps. lastIpcObject
                        // is filled from a `hyprctl clients` refresh, which
                        // lags — relying on it alone made every freshly opened
                        // window show the grey fallback icon for a few seconds.
                        readonly property string cls: {
                            const w = modelData.wayland;
                            if (w && w.appId && w.appId.length > 0)
                                return w.appId;
                            const o = modelData.lastIpcObject;
                            return o && o.class ? o.class : "";
                        }
                        readonly property bool focused: modelData.activated
                        readonly property bool urgent: modelData.urgent

                        implicitWidth: 28
                        implicitHeight: 26
                        Layout.alignment: Qt.AlignVCenter

                        Rectangle {
                            id: bg
                            anchors.fill: parent
                            radius: Theme.radiusSm
                            color: task.urgent ? Theme.a(Theme.crit, 0.18) : task.focused ? Theme.a(Theme.acc, 0.13) : ma.containsMouse ? Theme.chipHi : "transparent"
                            border.width: 1
                            border.color: task.urgent ? Theme.a(Theme.crit, 0.5) : task.focused ? Theme.a(Theme.acc, 0.42) : ma.containsMouse ? Theme.bdrHi : "transparent"

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
                        }

                        // The app's REAL icon from the theme (Papirus-Dark), with
                        // the coloured Nerd Font glyph as the fallback for
                        // anything the theme doesn't know.
                        readonly property string iconUrl: Apps.iconSource(task.cls)

                        IconImage {
                            id: appIcon
                            anchors.centerIn: parent
                            // Nudge up by 1px so the underline doesn't crowd it.
                            anchors.verticalCenterOffset: -1
                            implicitSize: 18
                            source: task.iconUrl
                            asynchronous: true
                            visible: task.iconUrl.length > 0 && status !== Image.Error

                            opacity: task.focused ? 1.0 : (ma.containsMouse ? 1.0 : 0.75)
                            scale: ma.containsMouse ? 1.16 : 1.0
                            y: ma.containsMouse ? -1 : 0

                            Behavior on opacity {
                                NumberAnimation {
                                    duration: Theme.animFast
                                }
                            }
                            Behavior on scale {
                                NumberAnimation {
                                    duration: Theme.animFast
                                    easing.type: Easing.OutBack
                                }
                            }
                            Behavior on y {
                                NumberAnimation {
                                    duration: Theme.animFast
                                }
                            }
                        }

                        Text {
                            id: glyph
                            anchors.centerIn: parent
                            anchors.verticalCenterOffset: -1
                            visible: !appIcon.visible
                            text: Apps.iconFor(task.cls)
                            color: Apps.colorFor(task.cls)
                            font.family: Theme.font
                            font.pixelSize: 15

                            // Hover lift: unfocused icons sit slightly dimmed, so
                            // hovering reads as the icon coming forward.
                            opacity: task.focused ? 1.0 : (ma.containsMouse ? 1.0 : 0.72)
                            scale: ma.containsMouse ? 1.16 : 1.0
                            y: ma.containsMouse ? -1 : 0

                            Behavior on opacity {
                                NumberAnimation {
                                    duration: Theme.animFast
                                }
                            }
                            Behavior on scale {
                                NumberAnimation {
                                    duration: Theme.animFast
                                    easing.type: Easing.OutBack
                                }
                            }
                            Behavior on y {
                                NumberAnimation {
                                    duration: Theme.animFast
                                }
                            }
                        }

                        // Accent underline marks the focused window.
                        Rectangle {
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 2
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: task.focused ? 14 : (ma.containsMouse ? 8 : 0)
                            height: 2
                            radius: 1
                            color: task.urgent ? Theme.crit : Theme.acc

                            Behavior on width {
                                NumberAnimation {
                                    duration: Theme.animFast
                                    easing.type: Easing.OutCubic
                                }
                            }
                        }

                        MouseArea {
                            id: ma
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            acceptedButtons: Qt.LeftButton | Qt.MiddleButton

                            onClicked: function (mouse) {
                                if (mouse.button === Qt.MiddleButton) {
                                    if (task.modelData.wayland)
                                        task.modelData.wayland.close();
                                } else if (task.modelData.wayland) {
                                    task.modelData.wayland.activate();
                                } else {
                                    // Fallback if the wayland handle is missing.
                                    Hyprland.dispatch("hl.dsp.focus({ window = \"address:" + task.modelData.address + "\" })");
                                }
                            }
                        }

                        // Native tooltip would need a popup window; the title is
                        // long and the icon is small, so keep it lightweight.
                        HoverHandler {
                            id: hh
                        }
                    }
                }
            }
        }
    }
}
