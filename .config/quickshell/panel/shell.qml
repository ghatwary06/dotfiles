import Quickshell
import Quickshell.Io
import QtQuick

// ===========================================================================
//  Side panel shell — run with:  qs -c panel
//
//  Owns:
//    · the right-edge slide-out panel (system / notifications / network)
//    · notification popups (this shell is the freedesktop notification daemon)
//
//  Driven from waybar over IPC:
//    qs -c panel ipc call panel  toggle
//    qs -c panel ipc call panel  open <system|notifications|network>
//    qs -c panel ipc call notifs toggleDnd
// ===========================================================================
ShellRoot {

    // Left bar cluster: workspace pills + running-apps taskbar, one per monitor.
    BarStrip {}

    SidePanel {
        id: panel
    }

    Dashboard {
        id: dash
    }

    Toasts {}

    // Clicking a popup jumps straight to the history view.
    Connections {
        target: Notifs
        function onOpened() {
            panel.show("notifications");
        }
    }

    IpcHandler {
        target: "panel"

        function toggle(): void {
            panel.toggle("");
        }

        function open(tab: string): void {
            panel.show(tab);
        }

        function close(): void {
            panel.open = false;
        }

        // Same entry point twice = close, which is what a bar button should do.
        function tab(name: string): void {
            panel.toggle(name);
        }
    }

    // Lets the chat be driven from outside the panel — a keybind, a rofi prompt,
    // or the terminal — and is also how the send path gets exercised without a
    // human typing into the box.
    // Brightness over IPC, so a keybind can drive the SAME code path the panel
    // uses — including the debounce and the DDC write lock.
    IpcHandler {
        target: "brightness"

        function set(display: string, value: int): void {
            if (display === "external")
                Brightness.setExternal(value);
            else
                Brightness.setLaptop(value);
        }

        function step(display: string, delta: int): void {
            if (display === "external")
                Brightness.setExternal(Brightness.external + delta);
            else
                Brightness.setLaptop(Brightness.laptop + delta);
        }

        function get(): string {
            return "laptop=" + Brightness.laptop + " external=" + Brightness.external;
        }

        function refresh(): void {
            Brightness.refresh();
        }
    }

    IpcHandler {
        target: "chat"

        function ask(text: string): void {
            panel.show("chat");
            Chat.send(text);
        }

        function clear(): void {
            Chat.clear();
        }

        function busy(): bool {
            return Chat.busy;
        }

        function last(): string {
            const m = Chat.messages;
            return m.length > 0 ? m[m.length - 1].text : "";
        }
    }

    IpcHandler {
        target: "dash"

        function toggle(): void {
            dash.toggle();
        }

        function open(): void {
            dash.show();
        }

        function close(): void {
            dash.open = false;
        }
    }

    // Media control over IPC — handy for keybinds, and it makes the seek path
    // exercisable without a mouse.
    IpcHandler {
        target: "media"

        function toggle(): void {
            Media.toggle();
        }

        function next(): void {
            Media.next();
        }

        function previous(): void {
            Media.previous();
        }

        // percent is 0-100 across the current track.
        function seek(percent: int): void {
            Media.seekFraction(percent / 100);
        }

        function status(): string {
            if (!Media.has)
                return "no player";
            return Media.identity + " | " + (Media.playing ? "playing" : "paused") + " | " + Media.title + " | " + Media.fmt(Media.position) + " / " + Media.fmt(Media.length) + " | seekable=" + Media.seekable;
        }
    }

    // Process actions, mirroring what the panel's table does. Scriptable, and
    // it lets the kill/sort paths be exercised without a mouse.
    IpcHandler {
        target: "procs"

        function terminate(pid: int): void {
            Sys.killPid(pid, false);
        }

        function force(pid: int): void {
            Sys.killPid(pid, true);
        }

        function sort(key: string): string {
            if (!Sys.setProcSort(key))
                return "invalid key (cpu|mem|name|pid)";
            return "sorted by " + Sys.procSort + (Sys.procSortDesc ? " desc" : " asc");
        }

        function top(): string {
            const list = (Sys.procs || []).slice();
            list.sort((a, b) => b.cpu - a.cpu);
            return list.slice(0, 3).map(p => p.name + ":" + p.pid + ":" + p.cpu + "%").join("  ");
        }
    }

    IpcHandler {
        target: "notifs"

        function toggleDnd(): void {
            Notifs.toggleDnd();
        }

        function clear(): void {
            Notifs.clearAll();
        }

        function count(): int {
            return Notifs.count;
        }
    }
}
