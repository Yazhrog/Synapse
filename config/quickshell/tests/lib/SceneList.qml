import QtQuick
import qs.src.features.audio
import qs.src.features.bar.center
import qs.src.features.bar.left
import qs.src.features.bar.right
import qs.src.features.clipboard
import qs.src.features.dashboard
import qs.src.features.dashboard.config
import qs.src.features.network
import qs.src.features.notifications
import qs.src.features.osd
import qs.src.features.power
import qs.src.features.screenrec
import qs.src.features.wallpaper
import qs.src.state
import qs.src.surface.shape
// SceneList — every view the shell can show, one scene each, at the size the
// Dynamic Surface gives it (the PopupSpec's place() at scale 1).
// Used by tests/smoke-registries.qml (each scene loads without a QML error)
// and tests/golden.qml (each scene is captured for the before/after
// comparison of tests/golden.sh).
//
// Scene: { name, w, h, setup(), component, clock }
//   name     stable id: the golden image file name, kept across moves/renames
//   w, h     size of the host item (0 = the item's implicit size)
//   setup()  runs before the scene loads (pages live in Popups)
//   clock    shows the time or date: only comparable with a fake clock
//
// Layer-shell windows (ConfirmDialog, BatteryCriticalDialog, UpdatePopup)
// can't be created offscreen; their cards join as plain components when
// they are split (#116).
QtObject {
    id: root

    function _dash(page)    { return () => { Popups.dashboardPage = page } }
    function _audio(page)   { return () => { Popups.audioPage = page } }
    function _none()        { return () => {} }

    readonly property var scenes: [
        // ── Frame shapes (closed, and with every region open) ───────────────
        { name: "shape-frame",        w: 1920, h: 1080, setup: _none(), component: shapeFrame },
        { name: "shape-bar",          w: 1920, h: 1080, setup: _none(), component: shapeBar },
        { name: "shape-pills",        w: 1920, h: 1080, setup: _none(), component: shapePills },
        { name: "shape-frame-open",   w: 1920, h: 1080, setup: _none(), component: shapeFrameOpen },
        { name: "shape-pills-open",   w: 1920, h: 1080, setup: _none(), component: shapePillsOpen },

        // ── Bar notch contents ──────────────────────────────────────────────
        { name: "bar-left",           w: 0, h: 0, setup: _none(), component: barLeft },
        { name: "bar-center",         w: 0, h: 0, setup: _none(), component: barCenter },
        { name: "bar-right",          w: 0, h: 0, setup: _none(), component: barRight,  clock: true },

        // ── Dashboard pages ─────────────────────────────────────────────────
        { name: "dashboard-home",     w: 884, h: 489, setup: _dash("home"),     component: dashboard, clock: true },
        { name: "dashboard-stats",    w: 884, h: 489, setup: _dash("stats"),    component: dashboard },
        { name: "dashboard-kanban",   w: 884, h: 489, setup: _dash("kanban"),   component: dashboard },
        { name: "dashboard-launcher", w: 544, h: 489, setup: _dash("launcher"), component: dashboard },
        { name: "dashboard-config",   w: 884, h: 489, setup: _dash("config"),   component: dashboard },

        // ── Config tabs ─────────────────────────────────────────────────────
        { name: "config-general",     w: 868, h: 449, setup: _none(), component: configGeneral },
        { name: "config-appearance",  w: 868, h: 449, setup: _none(), component: configAppearance },
        { name: "config-layout",      w: 868, h: 449, setup: _none(), component: configLayout },
        { name: "config-data",        w: 868, h: 449, setup: _none(), component: configData },
        { name: "config-keybinds",    w: 868, h: 449, setup: _none(), component: configKeybinds },
        { name: "config-misc",        w: 868, h: 449, setup: _none(), component: configMisc },

        // ── Network popup tabs ──────────────────────────────────────────────
        { name: "network-wifi",       w: 467, h: 576, setup: _none(), component: networkWifi },
        { name: "network-bluetooth",  w: 467, h: 576, setup: _none(), component: networkBluetooth },
        { name: "network-vpn",        w: 467, h: 576, setup: _none(), component: networkVpn },
        { name: "network-hotspot",    w: 467, h: 576, setup: _none(), component: networkHotspot },

        // ── Audio popup pages ───────────────────────────────────────────────
        { name: "audio-output",       w: 184, h: 294, setup: _audio("output"), component: audio },
        { name: "audio-input",        w: 184, h: 294, setup: _audio("input"),  component: audio },
        { name: "audio-mixer",        w: 284, h: 294, setup: _audio("mixer"),  component: audio },

        // ── Other popups and passive content ────────────────────────────────
        { name: "power-menu",         w: 216, h: 258, setup: _none(), component: powerMenu },
        { name: "notifications",      w: 392, h: 120,   setup: _none(), component: notifications },
        { name: "clipboard",          w: 410, h: 544, setup: _none(), component: clipboard },
        { name: "wallpaper",          w: 1010, h: 420, setup: _none(), component: wallpaper },
        { name: "osd",                w: 164, h: 276, setup: _none(), component: osd },
        { name: "screenrec-options",  w: 0, h: 0,   setup: _none(), component: screenRecOptions }
    ]

    // ── Components ──────────────────────────────────────────────────────────
    readonly property Component shapeFrame: Component { SurfaceShape { style: "frame" } }
    readonly property Component shapeBar:   Component { SurfaceShape { style: "bar" } }
    readonly property Component shapePills: Component { SurfaceShape { style: "pills" } }
    readonly property Component shapeFrameOpen: Component {
        SurfaceShape {
            style: "frame"
            centerWidth: 900; centerBottom: 520
            rightWidth: 504;  rightBottom: 648
            leftCenterDepth: 228; leftCenterHeight: 270
            bottomCenterWidth: 980; bottomCenterHeight: 420
        }
    }
    readonly property Component shapePillsOpen: Component {
        SurfaceShape {
            style: "pills"
            centerWidth: 900; centerBottom: 520
            rightCenterDepth: 200; rightCenterHeight: 306
            bottomRightWidth: 420; bottomRightHeight: 560
        }
    }

    readonly property Component barLeft:   Component { LeftContent {} }
    readonly property Component barCenter: Component { CenterContent {} }
    readonly property Component barRight:  Component { RightContent {} }

    readonly property Component dashboard: Component { DashboardContent {} }

    readonly property Component configGeneral:    Component { ShellConfig { _page: "general" } }
    readonly property Component configAppearance: Component { ShellConfig { _page: "appearance" } }
    readonly property Component configLayout:     Component { ShellConfig { _page: "layout" } }
    readonly property Component configData:       Component { ShellConfig { _page: "data" } }
    readonly property Component configKeybinds:   Component { ShellConfig { _page: "keybinds" } }
    readonly property Component configMisc:       Component { ShellConfig { _page: "misc" } }

    readonly property Component networkWifi:      Component { NetworkContent { page: "wifi" } }
    readonly property Component networkBluetooth: Component { NetworkContent { page: "bluetooth" } }
    readonly property Component networkVpn:       Component { NetworkContent { page: "vpn" } }
    readonly property Component networkHotspot:   Component { NetworkContent { page: "hotspot" } }

    readonly property Component audio:         Component { AudioControl {} }
    readonly property Component powerMenu:     Component { PowerMenu {} }
    readonly property Component notifications: Component { NotificationList {} }
    readonly property Component clipboard:     Component { HistoryTab {} }
    readonly property Component wallpaper:     Component { WallpaperContent { open: true } }
    readonly property Component osd:           Component { QuickControlContent {} }
    readonly property Component screenRecOptions: Component { ScreenRecOptions {} }
}
