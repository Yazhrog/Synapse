// Smoke test: loads the shell's singletons and the shared UI components in an
// offscreen window, then quits. Run by tests/smoke.sh (and CI); any QML error
// in the log fails the run. Layer-shell windows (bar, surface, popups) can't
// be created offscreen, so their contents are loaded on their own here.
import Quickshell
import QtQuick
import qs.src.components
import qs.src.modules.Center
import qs.src.modules.Right
import qs.src.popups
import qs.src.services
import qs.src.services.config_tab
import qs.src.services.network
import qs.src.shapes
import qs.src.state
import qs.src.theme
import qs.src.utils
ShellRoot {
    property var _singletons: [Theme, Paths, PrefsService, SurfaceState, Popups, ToastState,
                               ShellState, KeybindService, UpdateService, IpcManager,
                               FocusModeService, CavaService, AppearanceService, DataService, ClockState,
                               BrightnessService, QuickToggleService, HotspotService, ScreenFilterService,
                               KanbanService, WifiService, BluetoothService, VpnService,
                               ActiveWindowService]

    FloatingWindow {
        implicitWidth: 1920; implicitHeight: 1080
        SurfaceShape {
            anchors.fill: parent
            leftCenterDepth: 228; leftCenterHeight: 270
            bottomCenterWidth: 980; bottomCenterHeight: 420
            bottomRightWidth: 420; bottomRightHeight: 560
        }
        Column {
            DashboardContent    { width: 884; height: 489 }
            NetworkContent      { width: 467; height: 576 }
            WallpaperContent    { width: 1010; height: 420 }
            PowerMenu           { width: 216 }
            AudioControl        { width: 184; height: 294 }
            QuickControlContent { width: 164; height: 276 }
            ToastCard           { width: 360 }
            ScreenRecOptions    {}
            MiscPage            { width: 600; height: 300 }
            GeneralPage         { width: 600; height: 460 }
            AppearancePage      { width: 600; height: 300 }
            DataPage            { width: 600; height: 460 }
            Row { Clock {} Battery {} Audio {} }
            CenterContent       {}
        }
    }

    Timer {
        interval: 3000; running: true
        onTriggered: { console.log("SMOKE OK"); Qt.quit() }
    }
}
