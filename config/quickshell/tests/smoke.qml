// Smoke test: loads the shell's singletons and the shared UI components in an
// offscreen window, then quits. Run by tests/smoke.sh (and CI); any QML error
// in the log fails the run. Layer-shell windows (bar, surface, popups) can't
// be created offscreen, so their contents are loaded on their own here.
import Quickshell
import QtQuick
import qs.src.actions
import qs.src.components.feedback
import qs.src.core
import qs.src.features.audio
import qs.src.features.bar.center
import qs.src.features.bar.right
import qs.src.features.dashboard
import qs.src.features.dashboard.config.pages
import qs.src.features.dashboard.system
import qs.src.features.network
import qs.src.features.osd
import qs.src.features.power
import qs.src.features.screenrec
import qs.src.features.wallpaper
import qs.src.services.data
import qs.src.services.desktop
import qs.src.services.media
import qs.src.services.network
import qs.src.services.system
import qs.src.services.time
import qs.src.state
import qs.src.surface.shape
import qs.src.theme
ShellRoot {
    property var _singletons: [Theme, Paths, PrefsService, SurfaceState, Popups, ToastState,
                               ShellModes, KeybindService, UpdateService, IpcBridge, Actions,
                               FocusModeService, CavaService, AppearanceService, DataService, ClockService,
                               BrightnessService, QuickToggleService, HotspotService, ScreenFilterService,
                               TaskService, WifiService, BluetoothService, VpnService,
                               ActiveWindowService, PowerService, GpuModeService, AppsService,
                               KeyboardLayoutService, ProfileService, SystemInfoService, AudioService,
                               MediaService, Dialogs]

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
            Row { Clock {} BatteryIndicator {} AudioIndicator {} }
            CenterContent       {}
            SystemStats         { width: 400; height: 300 }
        }
    }

    Timer {
        interval: 3000; running: true
        onTriggered: { console.log("SMOKE OK"); Qt.quit() }
    }
}
