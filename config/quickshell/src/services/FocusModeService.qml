pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../"

// FocusModeService — Focus Mode: hides the bar and tightens Hyprland's gaps.
//
// Turning it on saves the current gaps_in/gaps_out and sets 0/10; turning it
// off restores them. ShellState.focusMode follows once hyprctl is done. Toggled
// from Quick Settings and the focus-toggle IPC; with the "Boot into Focus Mode"
// pref (Config → General) it turns on once at startup.
//
// The saved gaps are also written to $XDG_RUNTIME_DIR/synapse-focus-gaps.json,
// so a shell restarted while Focus Mode is on (crash, factory reset, hot
// reload) resumes it with the user's real gaps instead of saving 0/10 as the
// values to restore. Hyprland reports the gaps as CSS ("2 2 2 2"), which
// `hyprctl keyword` accepts back as is.
Singleton {
    id: root

    readonly property string focusIn:  "0"
    readonly property string focusOut: "10"
    readonly property string _stateFile:
        (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/synapse-focus-gaps.json"

    // The gaps to restore when Focus Mode turns off (CSS strings).
    property var _saved: ({ in: "2", out: "12" })

    function toggle() {
        if (ShellState.focusMode) root._restore()
        else root._probe("on")
    }

    // "2 2 2 2" and "2" are both gap 2 on every side.
    function _isGap(css, value) {
        const parts = String(css).trim().split(/\s+/)
        return parts.length > 0 && parts.every(p => p === value)
    }

    function _restore() {
        _restoreProc.command = ["bash", "-c",
            "hyprctl keyword general:gaps_in " + Paths.shellQuote(root._saved.in) +
            " && hyprctl keyword general:gaps_out " + Paths.shellQuote(root._saved.out) +
            "; rm -f " + Paths.shellQuote(root._stateFile)]
        _restoreProc.running = false
        _restoreProc.running = true
    }

    function _enter(saved) {
        root._saved = saved
        _applyProc.command = ["bash", "-c",
            "printf '%s' " + Paths.shellQuote(JSON.stringify(saved)) + " > " + Paths.shellQuote(root._stateFile) +
            "; hyprctl keyword general:gaps_in " + root.focusIn +
            " && hyprctl keyword general:gaps_out " + root.focusOut]
        _applyProc.running = false
        _applyProc.running = true
    }

    // Reads the current gaps and the saved ones, then continues in _onProbe.
    property string _probeMode: ""
    function _probe(mode) {
        if (_probeProc.running) return
        root._probeMode = mode
        _probeProc.running = true
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
                ShellState.focusMode = true
            } else if (PrefsService.bootFocusMode && !ShellState.focusMode) {
                root._enter({ in: r.in, out: r.out })
            }
            return
        }
        // Turning it on: never save the focus gaps as the ones to restore.
        root._enter(inFocus && saved ? saved : { in: r.in, out: r.out })
    }

    property Connections _ipc: Connections {
        target: IpcManager
        function onFocusToggleRequested() { root.toggle() }
    }

    property Connections _prefs: Connections {
        target: PrefsService
        function onLoaded() { root._probe("boot") }
    }

    Component.onCompleted: if (PrefsService.ready) root._probe("boot")

    property Process _probeProc: Process {
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
        stdout: StdioCollector {
            onStreamFinished: root._onProbe(text)
        }
    }

    property Process _applyProc: Process {
        onExited: ShellState.focusMode = true
    }

    property Process _restoreProc: Process {
        onExited: ShellState.focusMode = false
    }
}
