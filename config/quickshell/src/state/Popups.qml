pragma Singleton
import QtQuick
import "../"

QtObject {
    id: root

    // ── Per-popup open state ───────────────────────────────────────────────────
    // Read-only views of SurfaceState. Open and close popups with open(),
    // close(), toggle() and togglePage() below, never by assigning these.
    readonly property bool audioOpen:         SurfaceState.activeContent === "audio"
    readonly property bool networkOpen:       SurfaceState.activeContent === "network"
    readonly property bool batteryOpen:       SurfaceState.activeContent === "battery"
    readonly property bool notificationsOpen: SurfaceState.activeContent === "notifications"
    readonly property bool archMenuOpen:      SurfaceState.activeContent === "powerMenu"
    readonly property bool dashboardOpen:     SurfaceState.activeContent === "dashboard"
    readonly property bool wallpaperOpen:     SurfaceState.activeContent === "wallpaper"
    readonly property bool clipboardOpen:     SurfaceState.activeContent === "clipboard"

    // Passive content: not part of SurfaceState's single popup slot, so showing
    // them never closes an open popup. Use showQuick()/hideQuick() and
    // showToast()/hideToast().
    property bool notificationToastOpen: false
    property bool quickOpen:             false

    function showQuick()  { quickOpen = true }
    function hideQuick()  { quickOpen = false }
    function showToast()  { notificationToastOpen = true }
    function hideToast()  { notificationToastOpen = false }

    // ── Opening and closing ────────────────────────────────────────────────────
    // Content keys: dashboard, network, notifications, battery, audio,
    // powerMenu, wallpaper, clipboard (see SurfaceState.regionOf). The screen
    // defaults to the focused monitor.
    function open(content, screenName)   { return SurfaceState.open(content, screenName ?? "") }
    function close(content)              { SurfaceState.close(content ?? "") }
    function toggle(content, screenName) { return SurfaceState.toggle(content, screenName ?? "") }
    function isOpen(content)             { return SurfaceState.isOpen(content) }

    // Pages of the popups that have tabs. togglePage() switches to `page` if
    // the popup is open on another page, opens it on `page` if closed (or if
    // another popup is open), and closes it if already open on `page`.
    readonly property var _pageProp: ({
        dashboard: "dashboardPage",
        audio:     "audioPage",
        network:   "networkPage"
    })

    function togglePage(content, page, screenName) {
        const prop = _pageProp[content]
        if (isOpen(content) && root[prop] !== page) {
            root[prop] = page
            return
        }
        if (isOpen(content)) {
            close()
            return
        }
        root[prop] = page
        open(content, screenName)
    }

    // ── Dashboard — per-page state ───────────────────────────────────────────
    property int    dashboardPageWidth: 900
    property string dashboardPage:      "home"
    
    // ── Audio popup — per-page state ─────────────────────────────────────────
    property string audioPage: "output"

    // ── Network popup — per-page content (string key) ─────────────────────────
    property string networkPage: "wifi"

    // ── Per-popup trigger hover state ─────────────────────────────────────────
    property bool archMenuTriggerHovered: false
    property bool audioTriggerHovered:         false
    property bool networkTriggerHovered:       false
    property bool batteryTriggerHovered:       false
    property bool notificationsTriggerHovered: false
    property bool wallpaperTriggerHovered:     false
    property bool quickTriggerHovered: false

    // ── Universal popup behavior settings ─────────────────────────────────────
    property int  slideDuration:   Theme.animDuration
    property int  hoverCloseDelay: Theme.animDuration + 200   // delay after hover leaves before closing

    // ── Confirm dialog ────────────────────────────────────────────────────────
    property bool   confirmOpen:    false
    property string confirmTitle:   ""
    property string confirmMessage: ""
    property string confirmLabel:   "Confirm"
    property string confirmAction:  ""
    property string confirmGfxMode: ""
    property bool   confirmRunning: false

    function showConfirm(title, message, label, action, gfxMode) {
        confirmTitle   = title
        confirmMessage = message
        confirmLabel   = label
        confirmAction  = action
        confirmGfxMode = gfxMode ?? ""
        confirmOpen    = true
        // Confirm dialog is Overlay-layer, same as Dashboard — close the
        // dashboard so it can't cover the dialog and block input to it.
        close("dashboard")
    }

    function cancelConfirm() {
        confirmOpen    = false
        confirmAction  = ""
        confirmGfxMode = ""
    }

    // ── Critical battery dialog ──────────────────────────────────────────────
    property bool batteryCriticalOpen:  false
    property int  batteryCriticalLevel: 0

    function showBatteryCritical(level) {
        batteryCriticalLevel = level
        batteryCriticalOpen  = true
        // Same reasoning as showConfirm(): Overlay-layer dialog must not be
        // hidden behind an open dashboard.
        close("dashboard")
    }

    function acknowledgeBatteryCritical() {
        batteryCriticalOpen = false
    }

    // ── Global state ──────────────────────────────────────────────────────────
    // quickOpen is deliberately excluded: it's a passive OSD (volume/brightness
    // keys), not an interactive popup, so it must never trigger PopupDismiss's
    // fullscreen click-catcher/keyboard-focus grab — it should just fade in and
    // back out on its own without disturbing whatever the user is doing.
    readonly property bool anyOpen: SurfaceState.anyOpen

    function closeAll() {
        SurfaceState.close()
        quickOpen = false
    }
}
