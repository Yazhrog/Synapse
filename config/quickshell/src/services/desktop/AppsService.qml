pragma Singleton
import QtQuick
import Quickshell
import qs.src.core
// AppsService — the installed applications (.desktop files read by
// scripts/list_apps.py) and launching them.
//
// apps: [{ id, name, exec, icon, … }] in the script's order. refresh()
// clears the list and reads it again (the launcher does it each time it is
// shown); `listed` follows, also when the script failed (empty list).
// launch(exec) starts the .desktop Exec line detached from the shell.
Singleton {
    id: root

    readonly property var  apps:    _apps
    readonly property bool loading: _loading

    signal listed()

    function refresh() {
        _loading = true
        _apps = []
        _list.run()
    }

    // The Exec line is a command line from a .desktop file, so it is parsed
    // by the shell (eval), but it goes in as an argument, not into the script.
    function launch(exec: string) {
        _launch.run(["bash", "-c", 'eval "setsid $1" &>/dev/null &', "--", exec])
    }

    // ── Implementation ──────────────────────────────────────────────────────
    property var  _apps: []
    property bool _loading: true

    property Exec _list: Exec {
        command: ["python3", Quickshell.shellDir + "/src/scripts/list_apps.py"]
        parse: out => JSON.parse(out)
        onSucceeded: list => root._apps = list
        onFailed: root._apps = []
        onFinished: {
            root._loading = false
            root.listed()
        }
    }

    property Exec _launch: Exec {}
}
