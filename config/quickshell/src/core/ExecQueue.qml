import QtQuick

// ExecQueue — runs commands one at a time, in the order they were queued.
//
//   queue.enqueue(["cliphist", "delete-query", text], ok => …)
//
// Each callback gets (ok, result, code, stderr) when its command ends; the
// next command starts right after. `busy` is true while any is queued.
QtObject {
    id: root

    readonly property bool busy: _exec.busy || _queue.length > 0

    function enqueue(argv: var, callback: var) {
        _queue = _queue.concat([{ argv: argv, callback: callback ?? null }])
        if (!_exec.busy && _current === null) _next()
    }

    function clear() { _queue = []; _exec.cancel(); _current = null }

    // ── Implementation ──────────────────────────────────────────────────────
    property var _queue: []
    property var _current: null

    function _next() {
        if (_queue.length === 0) { _current = null; return }
        _current = _queue[0]
        _queue = _queue.slice(1)
        _exec.run(_current.argv)
    }

    // The command has ended (Exec is idle again). The callback may enqueue
    // more: that starts right away (FIFO, the queue is empty or it is behind
    // the others), so the next one only starts here if nothing did. A
    // throwing callback can't stall the queue.
    function _done(ok, result, code, err) {
        const c = _current
        _current = null
        try {
            if (c && c.callback) c.callback(ok, result, code, err)
        } catch (e) {
            console.warn("ExecQueue: callback failed: " + e)
        } finally {
            if (!_exec.busy) _next()
        }
    }

    property Exec _exec: Exec {
        onSucceeded: result => root._done(true, result, 0, "")
        onFailed: (code, err) => root._done(false, "", code, err)
    }
}
