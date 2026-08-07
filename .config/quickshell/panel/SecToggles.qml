import Quickshell.Io
import QtQuick
import QtQuick.Layouts

// Functional quick toggles. State is read back from the same shell helpers
// waybar uses, so the bar and the panel can never disagree.
ColumnLayout {
    id: sec
    spacing: Theme.gap

    property bool wifiOn: false
    property string wifiSsid: ""
    property bool btOn: false
    property int btCount: 0
    property bool nightOn: false
    property bool busy: false

    function refresh() {
        state_.running = true;
    }

    function run(cmd) {
        busy = true;
        action.command = ["sh", "-c", cmd];
        action.running = true;
    }

    // One probe for every toggle, so a refresh is a single fork.
    Process {
        id: state_
        running: false
        command: ["sh", "-c", "printf '%s;%s;%s;%s;%s' \"$(nmcli -t radio wifi 2>/dev/null)\" \"$(nmcli -t -f active,ssid dev wifi 2>/dev/null | awk -F: '$1==\"yes\"{print $2; exit}')\" \"$(bluetoothctl show 2>/dev/null | grep -q 'Powered: yes' && echo on || echo off)\" \"$(bluetoothctl devices Connected 2>/dev/null | grep -c '^Device')\" \"$(pgrep -x gammastep >/dev/null && echo on || echo off)\""]
        stdout: StdioCollector {
            onStreamFinished: {
                const f = this.text.split(";");
                sec.wifiOn = f[0] === "enabled";
                sec.wifiSsid = f[1] || "";
                sec.btOn = f[2] === "on";
                sec.btCount = parseInt(f[3]) || 0;
                sec.nightOn = f[4] === "on";
            }
        }
    }

    Process {
        id: action
        running: false
        onExited: {
            sec.busy = false;
            sec.refresh();
        }
    }

    Timer {
        interval: 4000
        repeat: true
        running: sec.visible
        triggeredOnStart: true
        onTriggered: sec.refresh()
    }

    WCard {
        title: "QUICK TOGGLES"
        hint: "right-click → settings"

        GridLayout {
            Layout.fillWidth: true
            columns: 2
            rowSpacing: 6
            columnSpacing: 6

            WToggle {
                icon: sec.wifiOn ? "󰤨" : "󰤭"
                label: "Wi-Fi"
                sub: sec.wifiOn ? (sec.wifiSsid || "on") : "off"
                on: sec.wifiOn
                busy: sec.busy
                onActivated: sec.run(sec.wifiOn ? "nmcli radio wifi off" : "nmcli radio wifi on")
                onSecondary: sec.run("$HOME/.config/rofi/wifi-menu.sh")
            }

            WToggle {
                icon: sec.btOn ? (sec.btCount > 0 ? "󰂱" : "󰂯") : "󰂲"
                label: "Bluetooth"
                sub: sec.btOn ? (sec.btCount > 0 ? sec.btCount + " connected" : "on") : "off"
                on: sec.btOn
                busy: sec.busy
                onActivated: sec.run(sec.btOn ? "bluetoothctl power off" : "rfkill unblock bluetooth; bluetoothctl power on")
                onSecondary: sec.run("blueman-manager")
            }

            WToggle {
                icon: Notifs.dnd ? "󰂛" : "󰂚"
                label: "Do Not Disturb"
                sub: Notifs.dnd ? "silenced" : "notifying"
                on: Notifs.dnd
                onActivated: Notifs.toggleDnd()
            }

            WToggle {
                icon: sec.nightOn ? "󰖙" : "󰃝"
                label: "Night Light"
                sub: sec.nightOn ? "4000K" : "off"
                on: sec.nightOn
                busy: sec.busy
                onActivated: sec.run(sec.nightOn ? "pkill -x gammastep" : "setsid -f gammastep -P -O 4000 >/dev/null 2>&1")
            }
        }
    }
}
