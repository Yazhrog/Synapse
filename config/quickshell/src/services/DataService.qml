pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../"

// DataService — the reset, export and cleanup actions of Config → Data &
// Storage.
//
// Every action ends with finished(action, ok) so the page can show a ✓ (or
// a failure) on its button. Shell commands run one at a time; `busy` is true
// meanwhile. factoryReset() restarts the shell and never reports back.
Singleton {
    id: root

    signal finished(string action, bool ok)
    // Emitted once tasks.json has been emptied; KanbanBoard then empties its
    // in-memory columns.
    signal tasksCleared()

    readonly property bool busy: _proc.running
    // Human-readable size of Paths.cacheDir ("" = empty or missing).
    property string cacheSize: ""

    readonly property string _tasksFile: Paths.userData("tasks.json")

    // ── Preferences ──────────────────────────────────────────────────────────
    function resetPrefs() {
        PrefsService.resetAll()
        root.finished("prefs", true)
    }

    // Back to the default wallpaper, folder and colour scheme. Reports once
    // the default wallpaper is applied (that is when wallpaper.json is saved).
    property bool _wallpaperPending: false

    function resetWallpaper() {
        if (!WallpaperService.resetToDefaults()) {
            root.finished("wallpaper", false)
            return
        }
        root._wallpaperPending = true
    }

    property Connections _wallpaper: Connections {
        target: WallpaperService
        function onApplyFinished(ok) {
            if (!root._wallpaperPending) return
            root._wallpaperPending = false
            root.finished("wallpaper", ok)
        }
    }

    function resetAvatar() {
        PrefsService.reset("avatarPath")
        root.finished("avatar", true)
    }

    // ── Tasks & clipboard ────────────────────────────────────────────────────
    // Copies tasks.json to the Documents folder with a timestamp, then notifies.
    function exportTasks() {
        root._run("export",
            "dir=\"$(xdg-user-dir DOCUMENTS 2>/dev/null)\"; " +
            "[ -n \"$dir\" ] && [ \"$dir\" != \"$HOME\" ] || dir=\"$HOME/Documents\"; " +
            "mkdir -p \"$dir\" && " +
            "f=\"$dir/synapse_tasks_$(date +%Y-%m-%d_%H%M%S).json\" && " +
            "cp " + Paths.shellQuote(root._tasksFile) + " \"$f\" && " +
            "{ notify-send --app-name Synapse --icon document-save 'Tasks exported' \"$f\" || true; }")
    }

    // The board is emptied only once the file is (see _proc), so a refused or
    // failed write can't leave an empty board that saves over the tasks.
    function clearTasks() {
        root._run("tasks",
            "printf '%s' '{\"tasks\":[],\"nextId\":0}' > " + Paths.shellQuote(root._tasksFile))
    }

    // History and pins.
    function wipeClipboard() {
        ClipboardService.wipeAll()
        root.finished("clipboard", true)
    }

    // ── Cache & reset ────────────────────────────────────────────────────────
    function clearCache() {
        const d = Paths.shellQuote(Paths.cacheDir)
        root._run("cache", "[ ! -d " + d + " ] || find " + d + " -mindepth 1 -delete")
    }

    function refreshCacheSize() {
        if (_sizeProc.running) return
        _sizeProc.running = true
    }

    // Deletes user_data/ (except the installer's config_Provider.json) and the
    // cache, then restarts the shell. repo-path, monitors.lua and local.zsh live
    // outside user_data/ and stay. The deletion runs in a detached shell after
    // this quickshell has exited, so nothing in memory writes its file back.
    function factoryReset() {
        const ud    = Paths.shellQuote(Paths.userDataDir)
        const cache = Paths.shellQuote(Paths.cacheDir)
        const dir   = String(Quickshell.shellDir).replace(/\/+$/, "")
        const start = dir === Paths.home + "/.config/quickshell"
            ? "quickshell" : "quickshell -p " + Paths.shellQuote(dir)
        const script =
            "kill \"$1\"; " +
            "for i in $(seq 50); do kill -0 \"$1\" 2>/dev/null || break; sleep 0.1; done; " +
            "[ ! -d " + ud + " ] || find " + ud + " -mindepth 1 -maxdepth 1 ! -name config_Provider.json -exec rm -rf {} +; " +
            "rm -rf " + cache + "; " +
            "exec " + start + " >/dev/null 2>&1 </dev/null"
        // $PPID of this bash is quickshell itself.
        _resetProc.command = ["bash", "-c",
            "setsid -f bash -c " + Paths.shellQuote(script) + " _ \"$PPID\""]
        _resetProc.running = true
    }

    // ── Runner ───────────────────────────────────────────────────────────────
    property string _action: ""

    function _run(action, cmd) {
        if (_proc.running) {
            root.finished(action, false)
            return
        }
        root._action = action
        _proc.command = ["bash", "-c", cmd]
        _proc.running = true
    }

    property Process _proc: Process {
        onExited: function(exitCode) {
            const action = root._action
            root._action = ""
            if (action === "cache") root.refreshCacheSize()
            if (action === "tasks" && exitCode === 0) root.tasksCleared()
            root.finished(action, exitCode === 0)
        }
    }

    property Process _sizeProc: Process {
        command: ["bash", "-c",
            "[ -d " + Paths.shellQuote(Paths.cacheDir) + " ] && [ -n \"$(ls -A " + Paths.shellQuote(Paths.cacheDir) + ")\" ] " +
            "&& du -sh " + Paths.shellQuote(Paths.cacheDir) + " | cut -f1 || true"]
        stdout: StdioCollector {
            onStreamFinished: root.cacheSize = text.trim()
        }
    }

    property Process _resetProc: Process {}
}
