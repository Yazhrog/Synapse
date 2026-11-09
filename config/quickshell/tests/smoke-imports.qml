// Import smoke test: loads the popup contents through the same imports the
// Dynamic Surface uses (windows/DynamicSurface.qml), and nothing else.
//
// Quickshell only finds files in folders it reaches by following
// `import "…"` lines from shell.qml; a folder that is only listed in a qmldir
// (services/home, services/config_tab, …) is not scanned unless some file
// imports it. tests/smoke.qml imports many folders itself, which hides that,
// so this run doesn't. Run by tests/smoke.sh.
import Quickshell
import QtQuick
import "./src/modules/Center/"
import "./src/modules/Right/"
import "./src/modules/Left/"
import "./src/shapes/"
import "./src/components/"
import "./src/services/"
import "./src/popups/"
import "./src/theme/"
import "./src/"

ShellRoot {
    FloatingWindow {
        implicitWidth: 1920; implicitHeight: 1080
        Column {
            DashboardContent { width: 884;  height: 489 }
            NetworkContent   { width: 467;  height: 576; page: Popups.networkPage || "wifi" }
            WallpaperContent { width: 1010; height: 420; open: true }
            CenterContent    {}
        }
    }

    // Visit every dashboard and network page, so their loaders and pages build.
    property var _steps: [
        () => Popups.dashboardPage = "stats",
        () => Popups.dashboardPage = "kanban",
        () => Popups.dashboardPage = "launcher",
        () => Popups.dashboardPage = "config",
        () => Popups.networkPage   = "bluetooth",
        () => Popups.networkPage   = "vpn",
        () => Popups.networkPage   = "hotspot"
    ]
    property int _step: 0
    Timer {
        interval: 250; repeat: true; running: true
        onTriggered: {
            if (_step < _steps.length) { _steps[_step](); _step++; return }
            console.log("SMOKE OK"); Qt.quit()
        }
    }
}
