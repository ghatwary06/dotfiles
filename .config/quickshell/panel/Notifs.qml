pragma Singleton

import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import QtQuick

// ===========================================================================
//  Notification daemon + history store.
//  This shell owns org.freedesktop.Notifications, which is why `exec-once =
//  dunst` is commented out in hyprland.conf — two daemons cannot both hold it.
//
//  State (unread count, DND flag) is mirrored into $XDG_RUNTIME_DIR/rice so
//  waybar can render its bell button without talking D-Bus, and waybar is
//  poked with RTMIN+8 on every change.
// ===========================================================================
Singleton {
    id: root

    property bool dnd: false
    property var items: []          // newest first — history
    property var popups: []         // currently on screen
    readonly property int count: items.length
    readonly property int maxHistory: 60
    readonly property int popupTimeout: 6000

    signal opened

    function toggleDnd() {
        dnd = !dnd;
        if (dnd)
            popups = [];
        _sync();
    }

    function dismiss(key) {
        items = items.filter(function (i) {
            if (i.key === key && i.notif) {
                try {
                    i.notif.dismiss();
                } catch (e) {}
            }
            return i.key !== key;
        });
        popups = popups.filter(i => i.key !== key);
        _sync();
    }

    function clearAll() {
        for (const i of items) {
            if (i.notif) {
                try {
                    i.notif.dismiss();
                } catch (e) {}
            }
        }
        items = [];
        popups = [];
        _sync();
    }

    function invoke(key, identifier) {
        const it = items.find(i => i.key === key);
        if (!it || !it.notif)
            return;
        for (const a of it.notif.actions) {
            if (a.identifier === identifier) {
                a.invoke();
                return;
            }
        }
    }

    function ageText(ts) {
        const s = Math.floor((Date.now() - ts) / 1000);
        if (s < 60)
            return "now";
        if (s < 3600)
            return Math.floor(s / 60) + "m";
        if (s < 86400)
            return Math.floor(s / 3600) + "h";
        return Math.floor(s / 86400) + "d";
    }

    // Push count + DND to disk and nudge waybar to re-read them.
    function _sync() {
        writer.command = ["sh", "-c", "d=\"${XDG_RUNTIME_DIR:-/tmp}/rice\"; mkdir -p \"$d\"; printf '%s' " + count + " > \"$d/notif-count\"; printf '%s' " + (dnd ? 1 : 0) + " > \"$d/dnd\"; pkill -RTMIN+8 waybar 2>/dev/null || true"];
        writer.running = true;
    }

    Process {
        id: writer
        running: false
    }

    Component.onCompleted: _sync()

    NotificationServer {
        id: server

        keepOnReload: false
        actionsSupported: true
        actionIconsSupported: true
        bodySupported: true
        bodyMarkupSupported: true
        imageSupported: true
        persistenceSupported: true

        onNotification: function (notification) {
            // Tracking keeps the object (and its actions) alive after the
            // signal returns, so history entries stay interactive.
            notification.tracked = true;

            const entry = {
                key: notification.id + ":" + Date.now(),
                summary: notification.summary || "",
                body: notification.body || "",
                appName: notification.appName || "",
                appIcon: notification.appIcon || "",
                image: notification.image || "",
                urgent: notification.urgency === NotificationUrgency.Critical,
                low: notification.urgency === NotificationUrgency.Low,
                time: Date.now(),
                notif: notification
            };

            root.items = [entry].concat(root.items).slice(0, root.maxHistory);

            // Critical notifications ignore DND, per the spec's intent.
            if (!root.dnd || entry.urgent)
                root.popups = [entry].concat(root.popups).slice(0, 4);

            root._sync();

            notification.closed.connect(function () {
                root.items = root.items.filter(i => i.key !== entry.key);
                root.popups = root.popups.filter(i => i.key !== entry.key);
                root._sync();
            });
        }
    }

    // Popups age out; history does not.
    Timer {
        interval: 1000
        repeat: true
        running: root.popups.length > 0
        onTriggered: {
            const now = Date.now();
            const keep = root.popups.filter(p => p.urgent || now - p.time < root.popupTimeout);
            if (keep.length !== root.popups.length)
                root.popups = keep;
        }
    }
}
