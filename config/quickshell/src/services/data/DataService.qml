pragma Singleton
import QtQuick
import Quickshell
import qs.src.core
import qs.src.services.desktop
// DataService — the reset, export and cleanup actions of Config → Data &
// Storage.
//
// Every action ends with finished(action, ok) so the page can show a ✓ (or
// a failure) on its button. Shell commands run one at a time; `busy` is true
// meanwhile; paths go to the scripts as arguments ($1…). factoryReset()
// restarts the shell and never reports back.
Singleton {
    id: root

    signal finished(string action, bool ok)

    readonly property bool busy: _exec.busy
    // Human-readable size of Paths.cacheDir ("" = empty or missing).
    property string cacheSize: ""

    // ── Preferences ──────────────────────────────────────────────────────────
    function resetPrefs() {
        Prefs.resetAll()
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
        Prefs.reset("avatarPath")
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
            "cp \"$1\" \"$f\" && " +
            "{ notify-send --app-name Synapse --icon document-save 'Tasks exported' \"$f\" || true; }",
            [TaskService.filePath])
    }

    // TaskService empties the file, then the board (only if the write worked).
    function clearTasks() {
        if (_exec.busy) {
            root.finished("tasks", false)
            return
        }
        TaskService.clear()
    }

    property Connections _kanban: Connections {
        target: TaskService
        function onClearFinished(ok) { root.finished("tasks", ok) }
    }

    // History and pins.
    function wipeClipboard() {
        ClipboardService.wipeAll()
        root.finished("clipboard", true)
    }

    // ── Cache & reset ────────────────────────────────────────────────────────
    function clearCache() {
        root._run("cache", '[ ! -d "$1" ] || find "$1" -mindepth 1 -delete', [Paths.cacheDir])
    }

    function refreshCacheSize() {
        if (!_size.busy) _size.run()
    }

    // Deletes user_data/ (except the installer's config_Provider.json) and the
    // cache, then restarts the shell. repo-path, monitors.lua and local.zsh live
    // outside user_data/ and stay. The deletion runs in a detached shell after
    // this quickshell has exited, so nothing in memory writes its file back.
    function factoryReset() {
        const dir = String(Quickshell.shellDir).replace(/\/+$/, "")
        // Empty when quickshell runs its default config (`quickshell`),
        // otherwise the dev checkout it was started with (`quickshell -p dir`).
        const custom = dir === Paths.home + "/.config/quickshell" ? "" : dir
        // Runs detached: $1 quickshell's pid, $2 user_data, $3 the cache, $4 custom.
        const script =
            "kill \"$1\"; " +
            "for i in $(seq 50); do kill -0 \"$1\" 2>/dev/null || break; sleep 0.1; done; " +
            "[ ! -d \"$2\" ] || find \"$2\" -mindepth 1 -maxdepth 1 ! -name config_Provider.json -exec rm -rf {} +; " +
            "rm -rf \"$3\"; " +
            "if [ -n \"$4\" ]; then exec quickshell -p \"$4\" >/dev/null 2>&1 </dev/null; " +
            "else exec quickshell >/dev/null 2>&1 </dev/null; fi"
        // In this outer bash $PPID is quickshell itself, $0 the script above.
        _reset.run(["bash", "-c", 'setsid -f bash -c "$0" _ "$PPID" "$1" "$2" "$3"',
                    script, Paths.userDataDir, Paths.cacheDir, custom])
    }

    // ── Runner ───────────────────────────────────────────────────────────────
    property string _action: ""

    // Runs `script` with `args` as $1, $2…; one action at a time.
    function _run(action, script, args) {
        if (_exec.busy) {
            root.finished(action, false)
            return
        }
        root._action = action
        _exec.run(["bash", "-c", script, "--"].concat(args ?? []))
    }

    property Exec _exec: Exec {
        onFinished: ok => {
            const action = root._action
            root._action = ""
            if (action === "cache") root.refreshCacheSize()
            root.finished(action, ok)
        }
    }

    property Exec _size: Exec {
        command: ["bash", "-c",
            '[ -d "$1" ] && [ -n "$(ls -A "$1")" ] && du -sh "$1" | cut -f1 || true',
            "--", Paths.cacheDir]
        onSucceeded: out => root.cacheSize = out.trim()
    }

    property Exec _reset: Exec {}
}
