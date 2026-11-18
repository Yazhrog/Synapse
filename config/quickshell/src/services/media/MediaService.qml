pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Mpris
// MediaService — the MPRIS players and which one the shell controls.
//
// `players` keeps only music sources (Spotify, YouTube, the browsers of
// `allowed`); `player` is the selected one, null when there is none. The
// selection follows its player when the list changes, else stays in range.
// `firstPlayer` is the first MPRIS player of any kind (the notch's music
// item). Intents act on `player` and do nothing when it can't.
Singleton {
    id: root

    readonly property var allowed: [
        "spotify", "youtube",
        "firefox", "chromium", "chrome",
        "brave", "edge", "opera", "vivaldi", "safari", "arc"
    ]

    // ── State ───────────────────────────────────────────────────────────────
    readonly property var players: {
        const _dep = _count          // re-evaluate when a player joins or leaves
        const out = []
        const vals = Mpris.players.values
        for (let i = 0; i < vals.length; i++) {
            const id = (vals[i].identity || "").toLowerCase()
            if (allowed.some(a => id.indexOf(a) !== -1)) out.push(vals[i])
        }
        return out
    }
    readonly property int  selectedIndex: _selected
    readonly property var  player:        players.length > 0 ? players[_selected] ?? null : null
    readonly property bool isPlaying:     player?.playbackState === MprisPlaybackState.Playing ?? false
    readonly property var  firstPlayer:   Mpris.players.values.length > 0 ? Mpris.players.values[0] : null

    // ── Intents ─────────────────────────────────────────────────────────────
    function select(index: int) {
        if (index < 0 || index >= players.length) return
        _selected = index
        _last = players[index]
    }
    function togglePlaying()    { if (player?.canTogglePlaying) player.isPlaying = !player.isPlaying }
    function previous()         { if (player?.canGoPrevious) player.previous() }
    function next()             { if (player?.canGoNext) player.next() }
    function seek(seconds: real) { if (player) player.position = seconds }

    // ── Implementation ──────────────────────────────────────────────────────
    property int _count: Mpris.players.values.length
    property int _selected: 0
    property var _last: null

    onPlayersChanged: {
        // Keep the same player selected; else clamp to the list.
        const i = _last ? players.indexOf(_last) : -1
        if (i !== -1) _selected = i
        else if (_selected >= players.length) _selected = Math.max(0, players.length - 1)
        _last = players[_selected] ?? null
    }
}
