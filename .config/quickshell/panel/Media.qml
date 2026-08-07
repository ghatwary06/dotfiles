pragma Singleton

import Quickshell
import Quickshell.Services.Mpris
import QtQuick

// ===========================================================================
//  MPRIS wrapper for the dashboard.
//  Picks a single "active" player: whatever is actually playing, else the
//  first one that exists — so the dashboard doesn't flicker between Spotify
//  and a browser tab that happens to also export MPRIS.
// ===========================================================================
Singleton {
    id: root

    readonly property var all: Mpris.players ? Mpris.players.values : []

    readonly property MprisPlayer player: {
        const list = all;
        if (!list || list.length === 0)
            return null;
        const playing = list.find(p => p.playbackState === MprisPlaybackState.Playing);
        return playing ?? list[0];
    }

    readonly property bool has: player !== null
    readonly property bool playing: has && player.playbackState === MprisPlaybackState.Playing

    readonly property string title: has && player.trackTitle ? player.trackTitle : ""
    readonly property string artist: has && player.trackArtist ? player.trackArtist : ""
    readonly property string album: has && player.trackAlbum ? player.trackAlbum : ""
    readonly property string art: has && player.trackArtUrl ? player.trackArtUrl : ""
    readonly property string identity: has ? (player.identity || "player") : ""

    readonly property bool seekable: has && player.canSeek && player.positionSupported
    readonly property real length: has && player.lengthSupported && player.length > 0 ? player.length : 0
    readonly property real position: has && player.positionSupported ? player.position : 0
    readonly property real progress: length > 0 ? Math.max(0, Math.min(1, position / length)) : 0

    function toggle() {
        if (has && player.canTogglePlaying)
            player.togglePlaying();
    }

    function next() {
        if (has && player.canGoNext)
            player.next();
    }

    function previous() {
        if (has && player.canGoPrevious)
            player.previous();
    }

    // fraction is 0..1 across the track.
    function seekFraction(fraction) {
        if (!seekable || length <= 0)
            return;
        player.position = Math.max(0, Math.min(length, fraction * length));
    }

    function fmt(seconds) {
        if (!isFinite(seconds) || seconds < 0)
            return "0:00";
        const t = Math.floor(seconds);
        const h = Math.floor(t / 3600);
        const m = Math.floor((t % 3600) / 60);
        const s = t % 60;
        const pad = n => (n < 10 ? "0" + n : "" + n);
        return h > 0 ? h + ":" + pad(m) + ":" + pad(s) : m + ":" + pad(s);
    }

    // MPRIS position is not push-based for most players; poll it while the
    // dashboard is open so the seek bar actually advances.
    property int watchers: 0

    function watch() {
        watchers++;
    }

    function unwatch() {
        watchers = Math.max(0, watchers - 1);
    }

    Timer {
        interval: 500
        repeat: true
        running: root.watchers > 0 && root.has
        onTriggered: {
            if (root.player)
                root.player.positionChanged();
        }
    }
}
