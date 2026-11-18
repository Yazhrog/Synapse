pragma Singleton
import QtQuick
import Quickshell
import qs.src.services.data
import qs.src.theme
Singleton {
    id: root

    // ── Per-popup open state ───────────────────────────────────────────────────
    // Read-only views of SurfaceState. Open and close popups with open(),
    // close(), toggle() and togglePage() below, never by assigning these.
    readonly property bool audioOpen:         SurfaceState.activeContent === "audio"
    readonly property bool networkOpen:       SurfaceState.activeContent === "network"
    readonly property bool notificationsOpen: SurfaceState.activeContent === "notifications"
    readonly property bool archMenuOpen:      SurfaceState.activeContent === "powerMenu"
    readonly property bool dashboardOpen:     SurfaceState.activeContent === "dashboard"
    readonly property bool wallpaperOpen:     SurfaceState.activeContent === "wallpaper"
    readonly property bool clipboardOpen:     SurfaceState.activeContent === "clipboard"

    // Passive OSD: not part of SurfaceState's single popup slot, so showing it
    // never closes an open popup. Use showQuick()/hideQuick(). (The toast is
    // driven by ToastState.)
    property bool quickOpen:             false
    property bool quickHeld:             false   // OSD hovered: don't auto-hide

    function showQuick()  { quickOpen = true }
    function hideQuick()  { quickOpen = false }

    // ── Opening and closing ────────────────────────────────────────────────────
    // Content keys: dashboard, network, notifications, audio,
    // powerMenu, wallpaper, clipboard (app/PopupManifest.qml). The screen
    // defaults to the focused monitor.
    // Opening a popup with tabs this way shows its default page (Config →
    // General); togglePage() picks the page itself.
    function open(content, screenName) {
        if (!isOpen(content)) _applyDefaultPage(content)
        return SurfaceState.open(content, screenName ?? "")
    }
    function close(content)              { SurfaceState.close(content ?? "") }
    function toggle(content, screenName) {
        if (!isOpen(content)) _applyDefaultPage(content)
        return SurfaceState.toggle(content, screenName ?? "")
    }
    function isOpen(content)             { return SurfaceState.isOpen(content) }

    // Pages of the popups that have tabs (PopupSpec.pageProp). togglePage()
    // switches to `page` if the popup is open on another page, opens it on
    // `page` if closed (or if another popup is open), and closes it if
    // already open on `page`.
    function togglePage(content, page, screenName) {
        const prop = SurfaceState.specOf(content)?.pageProp ?? ""
        if (prop === "") { toggle(content, screenName); return }
        if (isOpen(content) && root[prop] !== page) {
            root[prop] = page
            return
        }
        if (isOpen(content)) {
            close()
            return
        }
        root[prop] = page
        SurfaceState.open(content, screenName ?? "")
    }

    function _applyDefaultPage(content) {
        const spec = SurfaceState.specOf(content)
        if (!spec || spec.defaultPagePref === "") return
        const page = PrefsService[spec.defaultPagePref]
        if (page && page !== "last") root[spec.pageProp] = page
    }

    // ── Dashboard — per-page state ───────────────────────────────────────────
    // Width the dashboard grows to for the current page.
    readonly property var _dashboardPageWidths: ({
        home: 900, stats: 900, kanban: 900, launcher: 560, config: 900
    })
    readonly property int dashboardPageWidth: _dashboardPageWidths[dashboardPage] ?? 900
    property string dashboardPage:      "home"
    
    // ── Audio popup — per-page state ─────────────────────────────────────────
    property string audioPage: "output"

    // ── Network popup — per-page content (string key) ─────────────────────────
    property string networkPage: "wifi"

    // ── Hover behaviour ───────────────────────────────────────────────────────
    property int  hoverCloseDelay: Theme.animDuration + 200   // delay after hover leaves before closing

    // ── Global state ──────────────────────────────────────────────────────────
    // True while an interactive popup is open. The passive OSD and toast are
    // excluded: they must never enable the click shield or take the keyboard.
    readonly property bool anyOpen: SurfaceState.anyOpen

    function closeAll() {
        SurfaceState.close()
        quickOpen = false
    }
}
