// Import smoke test: loads every popup the way the Dynamic Surface hosts it,
// from app/PopupManifest.qml with nothing else imported, so each content
// must import everything it uses itself (with qs.* imports and no qmldir, a
// missing import fails here as "X is not a type"). Run by tests/smoke.sh.
import Quickshell
import QtQuick
import qs.src.app
import qs.src.state
ShellRoot {
    PopupManifest { id: manifest }

    // What the specs read from the DynamicSurface, at scale 1.
    readonly property var fakeSurface: ({
        px: v => Math.round(v), borderWidth: 2, notchRadius: 16, notchHeight: 34,
        notchBottom: 34, cornerRadius: 12, framed: true, width: 1920, height: 1080
    })

    FloatingWindow {
        implicitWidth: 1920; implicitHeight: 1080
        Column {
            Repeater {
                model: manifest.popups
                delegate: Loader {
                    required property var modelData
                    readonly property var  sz: modelData.size(fakeSurface, null)
                    readonly property rect p:  modelData.place(fakeSurface, sz[0], sz[1])
                    width: p.width; height: p.height
                    sourceComponent: modelData.component
                    onLoaded: {
                        if ("surface" in item) item.surface = fakeSurface
                        if (modelData.key === "dashboard") dash = item
                    }
                }
            }
            Loader { sourceComponent: manifest.osd; width: 164; height: 276 }
            Loader { sourceComponent: manifest.recordingOptions }
        }
    }

    property var dash: null

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
