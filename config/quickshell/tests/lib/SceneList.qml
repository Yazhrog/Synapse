import QtQuick
import qs.src.features.audio
import qs.src.features.bar
import qs.src.features.bar.center
import qs.src.features.clipboard
import qs.src.features.dashboard
import qs.src.features.dashboard.apps
import qs.src.features.dashboard.config
import qs.src.features.dashboard.home
import qs.src.features.dashboard.tasks
import qs.src.dialogs
import qs.src.features.network
import qs.src.features.notifications
import qs.src.features.osd
import qs.src.features.power
import qs.src.features.screenrec
import qs.src.features.wallpaper
import qs.src.state
import qs.src.surface
import qs.src.surface.shape
// SceneList — every view the shell can show, one scene each, at the size the
// Dynamic Surface gives it (the PopupSpec's place() at scale 1).
// Used by tests/smoke-registries.qml (each scene loads without a QML error)
// and tests/golden.qml (each scene is captured for the before/after
// comparison of tests/golden.sh).
//
// Scene: { name, w, h, setup(), component, props, clock }
//   name     stable id: the golden image file name, kept across moves/renames
//   w, h     size of the host item (0 = the item's implicit size)
//   setup()  runs before the scene loads (pages live in Popups)
//   props    optional properties set on the item once loaded
//   clock    shows the time or date: only comparable with a fake clock
//
// Layer-shell windows (ConfirmDialog, BatteryCriticalDialog, UpdatePopup)
// can't be created offscreen; their parts join as plain components.
QtObject {
    id: root

    function _dash(page)    { return () => { Popups.dashboardPage = page } }
    function _audio(page)   { return () => { Popups.audioPage = page } }
    function _none()        { return () => {} }

    readonly property var scenes: fixed.concat(generated)

    readonly property var fixed: [
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

        // ── Other popups and passive content ────────────────────────────────
        { name: "power-menu",         w: 216, h: 258, setup: _none(), component: powerMenu },
        { name: "notifications",      w: 392, h: 120,   setup: _none(), component: notifications },
        { name: "clipboard",          w: 410, h: 544, setup: _none(), component: clipboard },
        { name: "wallpaper",          w: 1010, h: 420, setup: _none(), component: wallpaper },
        { name: "osd",                w: 164, h: 276, setup: _none(), component: osd },
        { name: "screenrec-options",  w: 0, h: 0,   setup: _none(), component: screenRecOptions },

        // ── Parts that only show with data or on interaction ─────────────────
        { name: "player-card",        w: 360, h: 280, setup: _none(), component: playerCard },
        { name: "task-date-picker",   w: 400, h: 400, setup: _none(), component: taskDatePicker,
          props: { pickerTaskId: 0, pickerYear: 2025, pickerMonth: 5, pickerDay: 14, pickerHasTime: true } },
        { name: "app-tile",           w: 400, h: 46,  setup: _none(), component: appTile },
        { name: "clip-row",           w: 400, h: 0,   setup: _none(), component: clipRow },
        { name: "update-header",      w: 340, h: 0,   setup: _none(), component: updateHeader }
    ]


    // ── Scenes generated from the registries ────────────────────────────────
    // Every page, tab, bar widget and notch item, named <registry>-<key>, at
    // the size its host gives it.
    readonly property DashboardPages dashboardPages: DashboardPages {}
    readonly property ConfigTabs configTabs: ConfigTabs {}
    readonly property NetworkTabs networkTabs: NetworkTabs {}
    readonly property AudioPages audioPages: AudioPages {}
    readonly property BarWidgets barWidgets: BarWidgets {}
    readonly property NotchItems notchItems: NotchItems {}

    readonly property var generated: [].concat(
        Array.from(dashboardPages.pages, p => ({
            name: "dashboard-" + p.key, w: p.width - 16, h: 489, setup: _dash(p.key),
            component: dashboard, clock: p.key === "home" })),
        Array.from(configTabs.tabs, t => ({
            name: "config-" + t.key, w: 868, h: 449, setup: _none(), component: shellConfig, props: { _page: t.key } })),
        Array.from(networkTabs.pages, p => ({
            name: "network-" + p.key, w: 467, h: 576, setup: _none(), component: networkContent, props: { page: p.key } })),
        Array.from(audioPages.pages, p => ({
            name: "audio-" + p.key, w: p.width - 16, h: 294, setup: _audio(p.key), component: audio })),
        Array.from(barWidgets.widgets, w => ({
            name: "widget-" + w.key, w: 0, h: 0, setup: _none(), component: w.component,
            clock: w.key === "clock" })),
        Array.from(notchItems.items, n => ({
            name: "notch-" + n.key, w: 300, h: 30, setup: _none(), component: n.component }))
    )

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

    readonly property Component barLeft:   Component { BarZone { zone: "left";   spacing: 5; widgets: barWidgets.widgets } }
    readonly property Component barCenter: Component { BarZone { zone: "center";             widgets: barWidgets.widgets } }
    readonly property Component barRight:  Component { BarZone { zone: "right";  spacing: 6; widgets: barWidgets.widgets } }

    readonly property Component dashboard: Component { DashboardContent {} }

    readonly property Component shellConfig:    Component { ShellConfig {} }

    readonly property Component networkContent: Component { NetworkContent {} }

    readonly property Component audio:         Component { AudioControl {} }
    readonly property Component powerMenu:     Component { PowerMenu {} }
    readonly property Component notifications: Component { NotificationList {} }
    readonly property Component clipboard:     Component { HistoryTab {} }
    readonly property Component wallpaper:     Component { WallpaperContent { open: true } }
    readonly property Component osd:           Component { QuickControlContent {} }
    readonly property Component screenRecOptions: Component { ScreenRecOptions {} }
    readonly property Component playerCard:     Component { PlayerCard {} }
    readonly property Component taskDatePicker: Component { TaskDatePicker {} }
    readonly property Component appTile:        Component {
        AppTile { app: ({ id: "a", name: "Files", icon: "", exec: "", pinned: true }); selected: true }
    }
    readonly property Component clipRow:        Component { ClipRow { previewText: "Copied text"; isPinned: true } }
    readonly property Component updateHeader:   Component { UpdateHeader {} }
}
