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
Singleton {
    id: root

    property int _savedGapsIn:  5
    property int _savedGapsOut: 10

    function toggle() {
        if (ShellState.focusMode) {
            _restoreGaps.command = ["bash", "-c",
                "hyprctl keyword general:gaps_in "  + root._savedGapsIn +
                " && hyprctl keyword general:gaps_out " + root._savedGapsOut]
            _restoreGaps.running = false
            _restoreGaps.running = true
        } else {
            _readGapsIn.running = false
            _readGapsIn.running = true
        }
    }

    function _applyBootPref() {
        if (PrefsService.bootFocusMode && !ShellState.focusMode) root.toggle()
    }

    property Connections _ipc: Connections {
        target: IpcManager
        function onFocusToggleRequested() { root.toggle() }
    }

    property Connections _prefs: Connections {
        target: PrefsService
        function onLoaded() { root._applyBootPref() }
    }

    Component.onCompleted: if (PrefsService.ready) root._applyBootPref()

    property Process _readGapsIn: Process {
        command: ["bash", "-c",
            "hyprctl getoption general:gaps_in -j | python3 -c \"import sys,json; d=json.load(sys.stdin); print(d.get('int',5))\""]
        stdout: SplitParser {
            onRead: function(l) { const v = parseInt(l.trim()); if (!isNaN(v)) root._savedGapsIn = v }
        }
        onExited: { root._readGapsOut.running = false; root._readGapsOut.running = true }
    }

    property Process _readGapsOut: Process {
        command: ["bash", "-c",
            "hyprctl getoption general:gaps_out -j | python3 -c \"import sys,json; d=json.load(sys.stdin); print(d.get('int',10))\""]
        stdout: SplitParser {
            onRead: function(l) { const v = parseInt(l.trim()); if (!isNaN(v)) root._savedGapsOut = v }
        }
        onExited: { root._applyFocusGaps.running = false; root._applyFocusGaps.running = true }
    }

    property Process _applyFocusGaps: Process {
        command: ["bash", "-c", "hyprctl keyword general:gaps_in 0 && hyprctl keyword general:gaps_out 10"]
        onExited: ShellState.focusMode = true
    }

    property Process _restoreGaps: Process {
        onExited: ShellState.focusMode = false
    }
}
