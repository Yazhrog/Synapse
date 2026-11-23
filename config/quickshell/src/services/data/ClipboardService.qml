pragma Singleton
import QtQuick
import Quickshell
import qs.src.core
import "cliphist.js" as Cliphist

// ClipboardService — cliphist history and pinned entries, shared by every
// per-screen clipboard popup.
//
// History is read at startup, and while something holds a Lease on the
// service (the clipboard popup, while open): at once, then every 5 s. Pins
// live in user_data/clipboard_pins.json (a JsonStore). Every cliphist id
// and copied text goes to the command as an argument or on stdin, never
// into a shell string. History is wiped when the shell quits, and by a
// systemd user unit on logout / shutdown.
Singleton {
    id: root

    property var  entries: []
    readonly property var  pinned:  _pins.data
    readonly property bool loading: _list.busy

    // ── Lease: refresh while a view shows the history ───────────────────────
    readonly property bool watched: _leases.watched
    function acquire() { _leases.acquire() }
    function release() { _leases.release() }
    property LeaseCount _leases: LeaseCount {}

    property Poller _poll: Poller { interval: 5000; running: root.watched; onTick: root.load() }

    // ── History ─────────────────────────────────────────────────────────────
    function load() { _list.run() }

    property Exec _list: Exec {
        command: ["cliphist", "list"]
        parse: Cliphist.parseList
        onSucceeded: list => root.entries = list
        onFailed: root.entries = []
    }

    // ── Copy ────────────────────────────────────────────────────────────────
    property Exec _copy: Exec {}

    function copyEntry(id) {
        _copy.stdinText = ""
        _copy.run(["bash", "-c", 'cliphist decode "$1" 2>/dev/null | wl-copy', "--", id])
    }

    function copyText(t) {
        _copy.stdinText = t
        _copy.run(["wl-copy"])
    }

    // ── Image previews ──────────────────────────────────────────────────────
    // An image entry decoded to a temporary file, one at a time; then
    // previewReady(id, path) (also when decoding failed: the image just
    // doesn't load).
    signal previewReady(string id, string path)

    function previewPath(id) { return "/tmp/clip_prev_" + id }

    function decodePreview(id) {
        if (!id || id === "") return
        const path = previewPath(id)
        _previews.enqueue(["bash", "-c", 'cliphist decode "$1" > "$2" 2>/dev/null', "--", id, path],
                          () => root.previewReady(id, path))
    }

    property ExecQueue _previews: ExecQueue {}

    // ── Type: copy first, then wtype after popup closes ─────────────────────
    property Exec _wtype: Exec { command: ["bash", "-c", "sleep 0.35 && wl-paste -n | wtype -"] }

    function typeFromClipboard() { _wtype.run() }

    // ── Delete ──────────────────────────────────────────────────────────────
    property Exec _delete: Exec { onFinished: root.load() }

    function deleteEntry(id) {
        if (!id || id === "") return
        _delete.run(["bash", "-c",
            "cliphist list 2>/dev/null | awk -F'\\t' -v id=\"$1\" '$1==id' | cliphist delete 2>/dev/null",
            "--", id])
    }

    // ── Pin ─────────────────────────────────────────────────────────────────
    // Pin data format: { text, preview, id, timestamp }
    // - text:      full decoded content (used for copyText)
    // - preview:   cliphist list preview (used for dedup in the flat model)
    // - id:        cliphist row ID at pin time (used for deleteEntry; may be stale after wipe)
    // - timestamp: epoch ms
    property var _pinQueue: []

    function pinEntry(id, preview) {
        _pinQueue = _pinQueue.concat([{ id: id, preview: preview }])
        if (!_decode.busy) _decodeNext()
    }

    function _decodeNext() {
        if (_pinQueue.length > 0) _decode.run(["cliphist", "decode", _pinQueue[0].id])
    }

    property Exec _decode: Exec {
        onFinished: {
            const decoded = lastOutput.trim()
            const item = root._pinQueue[0]
            root._pinQueue = root._pinQueue.slice(1)
            if (decoded !== "" && item) {
                const list = root.pinned.filter(p => p.text !== decoded)
                list.unshift({ text: decoded, preview: item.preview, id: item.id, timestamp: new Date().getTime() })
                root._pins.set(list)
            }
            root._decodeNext()
        }
    }

    function unpinAt(index) {
        _pins.update(list => { list.splice(index, 1) })
    }

    property JsonStore _pins: JsonStore {
        path:            Paths.userData("clipboard_pins.json")
        defaults:        []
        createIfMissing: false
    }

    // ── Wipe ────────────────────────────────────────────────────────────────
    property Exec _wipe: Exec { command: ["cliphist", "wipe"]; onFinished: root.load() }

    function wipeHistory() { _wipe.run() }

    // History and pins (Config → Data & Storage).
    function wipeAll() {
        _pins.set([])
        wipeHistory()
    }

    // On quit: detached, so it outlives the shell process.
    Component.onDestruction: Quickshell.execDetached(["cliphist", "wipe"])

    // ── A systemd user unit that wipes on logout / shutdown ─────────────────
    property Exec _setupUnit: Exec {
        command: ["bash", "-c",
            "mkdir -p ~/.config/systemd/user && " +
            "printf '[Unit]\\nDescription=Wipe cliphist history on logout/shutdown\\n\\n" +
            "[Service]\\nType=oneshot\\nRemainAfterExit=true\\nExecStart=/usr/bin/true\\nExecStop=/usr/bin/cliphist wipe\\n\\n" +
            "[Install]\\nWantedBy=default.target\\n' " +
            "> ~/.config/systemd/user/cliphist-wipe.service && " +
            "systemctl --user daemon-reload && " +
            "systemctl --user enable --now cliphist-wipe.service 2>/dev/null || true"]
    }

    Component.onCompleted: {
        _setupUnit.run()
        load()
    }
}
