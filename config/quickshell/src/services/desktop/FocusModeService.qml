pragma Singleton
import QtQuick
import Quickshell
import qs.src.core
import qs.src.services.data
// FocusModeService — Focus Mode: hides the bar and tightens Hyprland's gaps.
//
// Turning it on saves the current gaps_in/gaps_out and sets 0/10; turning it
// off restores them. `active` follows once hyprctl is done (ShellModes.focusMode
// mirrors it for the surface). Toggled from Quick Settings and the
// focus-toggle IPC; with the "Boot into Focus Mode" pref (Config → General) it
// turns on once at startup.
//
// The saved gaps are also written to $XDG_RUNTIME_DIR/synapse-focus-gaps.json,
// so a shell restarted while Focus Mode is on (crash, factory reset, hot
// reload) resumes it with the user's real gaps instead of saving 0/10 as the
// values to restore. Hyprland reports the gaps as CSS ("2 2 2 2"); they're set
// through Hypr (the right syntax for the Lua or conf provider).
Singleton {
    id: root

    property bool active: false

    readonly property string focusIn:  "0"
    readonly property string focusOut: "10"
    readonly property string _stateFile:
        (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/synapse-focus-gaps.json"

    // The gaps to restore when Focus Mode turns off (CSS strings).
    property var _saved: ({ in: "2", out: "12" })

    function toggle() {
        if (active) root._restore()
        else root._probe("on")
    }

    // "2 2 2 2" and "2" are both gap 2 on every side.
    function _isGap(css, value) {
        const parts = String(css).trim().split(/\s+/)
        return parts.length > 0 && parts.every(p => p === value)
    }

    // CSS gap ("2", "2 4", "2 4 6", "2 4 6 8") → [top, right, bottom, left].
    function _sides(css) {
        const n = String(css).trim().split(/\s+/).map(v => Math.max(0, parseInt(v) || 0))
        if (n.length === 1) return [n[0], n[0], n[0], n[0]]
        if (n.length === 2) return [n[0], n[1], n[0], n[1]]
        if (n.length === 3) return [n[0], n[1], n[2], n[1]]
        return n.slice(0, 4)
    }

    // Sets both gaps (CSS strings) through Hypr; `done` once hyprctl is done.
    function _setGaps(inCss, outCss, done) {
        const side = css => { const s = _sides(css); return { top: s[0], right: s[1], bottom: s[2], left: s[3] } }
        Hypr.setOptions("general", { gaps_in: side(inCss), gaps_out: side(outCss) }, done)
    }

    function _restore() {
        _setGaps(_saved.in, _saved.out, () => {
            _rmState.run()
            root.active = false
        })
    }

    function _enter(saved) {
        _saved = saved
        _writeState.run(["sh", "-c", 'printf "%s" "$2" > "$1"', "--", _stateFile, JSON.stringify(saved)])
        _setGaps(focusIn, focusOut, () => root.active = true)
    }

    // Reads the current gaps and the saved ones, then continues in _onProbe.
    property string _probeMode: ""
    function _probe(mode) {
        if (_probeProc.busy) return
        root._probeMode = mode
        _probeProc.run()
    }

    function _onProbe(text) {
        let r = null
        try { r = JSON.parse(text) } catch (e) {}
        if (!r) return
        r.in  = r.in  || root._saved.in
        r.out = r.out || root._saved.out
        const inFocus = root._isGap(r.in, root.focusIn) && root._isGap(r.out, root.focusOut)
        const saved   = r.saved && r.saved.in && r.saved.out ? r.saved : null

        if (root._probeMode === "boot") {
            if (inFocus && saved) {
                // Restarted while Focus Mode was on: resume it.
                root._saved = saved
                root.active = true
            } else if (PrefsService.bootFocusMode && !root.active) {
                root._enter({ in: r.in, out: r.out })
            }
            return
        }
        // Turning it on: never save the focus gaps as the ones to restore.
        root._enter(inFocus && saved ? saved : { in: r.in, out: r.out })
    }

    property Connections _prefs: Connections {
        target: PrefsService
        function onLoaded() { root._probe("boot") }
    }

    Component.onCompleted: if (PrefsService.ready) root._probe("boot")

    property Exec _probeProc: Exec {
        command: ["python3", "-c",
            "import json, os, subprocess\n" +
            "def gap(k):\n" +
            "    try:\n" +
            "        d = json.loads(subprocess.run(['hyprctl', 'getoption', k, '-j'], capture_output=True, text=True).stdout)\n" +
            "        return str(d.get('css', d.get('int', '')))\n" +
            "    except Exception:\n" +
            "        return ''\n" +
            "try:\n" +
            "    saved = json.load(open(os.sys.argv[1]))\n" +
            "except Exception:\n" +
            "    saved = None\n" +
            "print(json.dumps({'in': gap('general:gaps_in'), 'out': gap('general:gaps_out'), 'saved': saved}))\n",
            root._stateFile]
        onFinished: root._onProbe(lastOutput)
    }

    property Exec _writeState: Exec {}
    property Exec _rmState: Exec { command: ["rm", "-f", root._stateFile] }
}
