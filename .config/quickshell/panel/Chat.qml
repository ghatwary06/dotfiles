pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// ===========================================================================
//  Chat state for the side panel, backed by the `claude` CLI (chat.sh).
//  No API key: it reuses the Claude Code login already on this machine, so a
//  turn here costs exactly what a turn in the terminal costs.
// ===========================================================================
Singleton {
    id: root

    // Completed turns only: [{ role: "user"|"assistant", text: string }].
    property var messages: []

    // The in-flight reply is kept OUT of `messages` on purpose. Appending each
    // token to an array element would mean reassigning the whole array on every
    // delta, which rebuilds every delegate in the list ~50x a second.
    property string streamText: ""
    property bool busy: false
    property string error: ""

    // Claude Code session id, so --resume can keep the thread alive across
    // turns. Empty means the next message starts a fresh conversation.
    property string sessionId: ""

    readonly property string chatPath: Quickshell.env("HOME") + "/.config/quickshell/panel/chat.sh"

    signal replied
    signal scrollWanted

    function send(text) {
        const t = String(text).trim();
        if (t.length === 0 || busy)
            return false;

        error = "";
        messages = messages.concat([
            {
                role: "user",
                text: t
            }
        ]);
        streamText = "";
        busy = true;
        scrollWanted();

        // argv, not a shell string — see chat.sh's header. "-" means "no session
        // yet", which is cleaner than passing an empty argument.
        proc.command = [chatPath, sessionId.length > 0 ? sessionId : "-", t];
        proc.running = true;
        return true;
    }

    function clear() {
        if (busy)
            proc.running = false;
        messages = [];
        streamText = "";
        sessionId = "";
        error = "";
        busy = false;
    }

    function stop() {
        if (!busy)
            return;
        proc.running = false;
        busy = false;
        // Keep whatever streamed in rather than throwing it away — a partial
        // answer is usually still worth reading.
        if (streamText.length > 0) {
            messages = messages.concat([
                {
                    role: "assistant",
                    text: streamText + "\n\n_(stopped)_"
                }
            ]);
            streamText = "";
        }
    }

    // Move whatever has streamed so far into the transcript as a finished
    // message. Returns whether anything was actually there.
    function _flushStream() {
        const t = streamText;
        streamText = "";
        if (t.trim().length === 0)
            return false;
        messages = messages.concat([
            {
                role: "assistant",
                text: t
            }
        ]);
        return true;
    }

    // One-line summary of a tool call, so the transcript reads like the
    // terminal does ("Bash: ls -la") instead of dumping a JSON blob.
    function _toolSummary(b) {
        const inp = b.input || {};
        const n = b.name || "tool";
        if (inp.command)
            return String(inp.command);
        if (inp.file_path)
            return String(inp.file_path);
        if (inp.path)
            return String(inp.path);
        if (inp.url)
            return String(inp.url);
        if (inp.pattern)
            return String(inp.pattern);
        if (inp.query)
            return String(inp.query);
        if (inp.prompt)
            return String(inp.prompt).slice(0, 120);
        // fall back to the first stringish value rather than "[object Object]"
        for (const k in inp) {
            const v = inp[k];
            if (typeof v === "string" && v.length > 0)
                return v.slice(0, 120);
        }
        return n;
    }

    function _line(line) {
        const s = String(line).trim();
        if (s.length === 0)
            return;

        let d;
        try {
            d = JSON.parse(s);
        } catch (e) {
            // stderr and CLI notices are not JSON; ignore rather than crash the
            // panel on a stray line.
            return;
        }

        if (d.session_id)
            sessionId = d.session_id;

        // Token deltas: type=stream_event -> event.content_block_delta.text_delta
        if (d.type === "stream_event") {
            const ev = d.event || {};
            if (ev.type === "content_block_delta") {
                const dl = ev.delta || {};
                if (dl.type === "text_delta" && dl.text) {
                    streamText += dl.text;
                    scrollWanted();
                }
            }
            return;
        }

        // With tools enabled a turn is several assistant messages: some text,
        // a tool_use, more text. Surface the tool calls in order so the panel
        // shows the work rather than going quiet mid-answer.
        if (d.type === "assistant") {
            const content = ((d.message || {}).content) || [];
            for (let i = 0; i < content.length; i++) {
                const b = content[i];
                if (b && b.type === "tool_use") {
                    _flushStream();          // close off any text before the call
                    messages = messages.concat([
                        {
                            role: "tool",
                            name: b.name || "tool",
                            text: _toolSummary(b)
                        }
                    ]);
                    scrollWanted();
                }
            }
            return;
        }

        if (d.type === "result") {
            // Flush the streamed tail FIRST. `d.result` repeats only the final
            // text, so using it as the primary source would drop everything the
            // model said before a tool call and duplicate what it said after.
            const tail = streamText;
            const flushed = _flushStream();

            if (d.is_error || d.subtype === "error") {
                error = (typeof d.result === "string" && d.result.length > 0) ? d.result : (tail || "the CLI returned an error");
            } else if (!flushed && typeof d.result === "string" && d.result.trim().length > 0) {
                // Nothing streamed — partial messages unavailable for this turn.
                messages = messages.concat([
                    {
                        role: "assistant",
                        text: d.result
                    }
                ]);
            }
            busy = false;
            replied();
            scrollWanted();
        }
    }

    Process {
        id: proc
        running: false

        stdout: SplitParser {
            onRead: line => root._line(line)
        }

        // The CLI writes progress notices to stderr; only surface them if the
        // run actually failed, otherwise they are noise.
        stderr: StdioCollector {}

        onExited: function (code) {
            if (root.busy) {
                // Exited without a `result` line — a crash, a bad session id, or
                // a killed process.
                root.busy = false;
                if (code !== 0 && root.error.length === 0) {
                    const e = String(stderr.text || "").trim();
                    root.error = e.length > 0 ? e.split("\n").slice(-3).join("\n") : ("claude exited with code " + code);
                    // A stale session id is the common cause; drop it so the
                    // next message starts clean instead of failing forever.
                    if (root.error.toLowerCase().indexOf("session") >= 0)
                        root.sessionId = "";
                }
                if (root.streamText.length > 0) {
                    root.messages = root.messages.concat([
                        {
                            role: "assistant",
                            text: root.streamText
                        }
                    ]);
                    root.streamText = "";
                }
                root.scrollWanted();
            }
        }
    }
}
