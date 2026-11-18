// Import smoke test: loads the popup contents with only the imports this file
// needs to name them, the way the Dynamic Surface hosts them, so each content
// must import everything it uses itself (with qs.* imports and no qmldir, a
// missing import fails here as "X is not a type"). Run by tests/smoke.sh.
import Quickshell
import QtQuick
import qs.src.features.bar.center
import qs.src.features.dashboard
import qs.src.features.network
import qs.src.features.wallpaper
import qs.src.state
ShellRoot {
    FloatingWindow {
        implicitWidth: 1920; implicitHeight: 1080
        Column {
            DashboardContent { id: dash; width: 884;  height: 489 }
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
        () => dash.reset(),
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
