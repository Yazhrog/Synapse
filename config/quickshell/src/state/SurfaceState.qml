pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.src.services.data
import qs.src.services.media
import qs.src.theme
// ============================================================
// SurfaceState — what interactive popup is open, on which screen, and in
// which phase of its lifecycle.
//
// One popup at a time, globally. The popups come from app/PopupManifest.qml
// (`popups`, set by App): their keys and regions are read from there. Code
// that opens or closes popups goes through Popups.open/close/toggle, which
// call here; Popups.xxxOpen are read-only views of this state.
//
// Lifecycle, per popup and screen:
//
//           open()           animation done
//   closed ───────► opening ────────────────► open
//     ▲                                         │ close(), another popup,
//     │ animation done                          │ Escape, click outside, …
//     └─────────────── closing ◄────────────────┘
//
// Each transition emits opening / opened / closing / closed(key, screen);
// views react through PopupLifecycle. activeContent switches at once (on
// opening and closing), so bindings on it keep their timing.
//
// Passive content (the volume/brightness OSD, notification toasts) is not
// tracked here: it must never close an open popup or take the keyboard.
// ============================================================

Singleton {
    id: root

    property string activeScreen:  ""       // screen name owning the open popup, "" = none
    property string activeRegion:  "none"
    property string activeContent: "none"

    readonly property bool anyOpen: activeContent !== "none"

    // ── Registry (app/PopupManifest.qml) ────────────────────────────────────
    property var popups: []

    readonly property var specs: {
        const m = {}
        for (let i = 0; i < popups.length; i++) m[popups[i].key] = popups[i]
        return m
    }
    readonly property var regionOf: {
        const m = {}
        for (let i = 0; i < popups.length; i++) m[popups[i].key] = popups[i].region
        return m
    }
    function specOf(key: string): var { return specs[key] ?? null }

    // ── Lifecycle ───────────────────────────────────────────────────────────
    signal opening(string key, string screen)
    signal opened(string key, string screen)
    signal closing(string key, string screen)
    signal closed(string key, string screen)

    // "closed", "opening", "open" or "closing". Without a screen: the phase
    // on the screen where the popup is (or was last) shown.
    function phaseOf(key: string, screen: var): string {
        if (screen) return _phases[key + "@" + screen] ?? "closed"
        if (activeContent === key) return _phases[key + "@" + activeScreen] ?? "closed"
        for (const k in _phases)
            if (k.startsWith(key + "@") && _phases[k] !== "closed") return _phases[k]
        return "closed"
    }

    // Open (opening or open) on that screen.
    function isOpenOn(key: string, screen: string): bool {
        return activeContent === key && activeScreen === screen
    }

    property var _phases: ({})   // "key@screen" → phase
    property var _gen:    ({})   // "key@screen" → transition count (stale timers do nothing)

    function _enter(key, screen, phase) {
        const id = key + "@" + screen
        const phases = Object.assign({}, _phases)
        phases[id] = phase
        _phases = phases
        _gen[id] = (_gen[id] ?? 0) + 1
        const gen = _gen[id]
        switch (phase) {
        case "opening":
            opening(key, screen)
            _after(Theme.animDuration, () => { if (_gen[id] === gen) _enter(key, screen, "open") })
            break
        case "open":    opened(key, screen); break
        case "closing":
            closing(key, screen)
            _after(Theme.animDuration + 20, () => { if (_gen[id] === gen) _enter(key, screen, "closed") })
            break
        case "closed":  closed(key, screen); break
        }
    }

    function _after(ms, fn) { _timer.createObject(root, { interval: ms, fn: fn }) }

    property Component _timer: Component {
        Timer {
            property var fn
            running: true
            onTriggered: { fn(); destroy() }
        }
    }

    function _focusedScreen(): string {
        return Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : ""
    }

    // The screen-recording setup owns the screen: nothing opens over it.
    readonly property bool _blocked: ShellModes.screenRecord && !ScreenRecService.recording

    // ── Resolution scaling ──────────────────────────────────────────────────
    // Surface sizes are designed for a 1080 px tall screen. The factor comes
    // from Prefs.data.surfaceScale: "off" → 1, "auto" → screen height / 1080
    // clamped to [0.75, 1.5] (on top of Hyprland's own monitor scale), or a
    // fixed number. SYNAPSE_SURFACE_SCALE overrides it for testing.
    readonly property real _forcedScale: Number(Quickshell.env("SYNAPSE_SURFACE_SCALE") ?? 0) || 0

    function scaleFor(screen): real {
        if (root._forcedScale > 0) return root._forcedScale
        const mode = Prefs.data.surfaceScale
        if (mode === "auto") {
            if (!screen || !screen.height) return 1.0
            return Math.max(0.75, Math.min(1.5, screen.height / 1080))
        }
        const fixed = Number(mode)
        return fixed > 0 ? Math.max(0.5, Math.min(2.0, fixed)) : 1.0
    }

    function isOpen(content: string): bool {
        return root.activeContent === content
    }

    function open(content, screenName) {
        if (!(content in root.regionOf)) {
            console.warn("SurfaceState: unknown content", content)
            return false
        }
        if (root._blocked) return false
        const screen = screenName || root._focusedScreen()
        if (root.activeContent === content && root.activeScreen === screen) return true
        const prev = root.activeContent, prevScreen = root.activeScreen
        root.activeScreen  = screen
        root.activeRegion  = root.regionOf[content]
        root.activeContent = content
        if (prev !== "none") _enter(prev, prevScreen, "closing")
        _enter(content, screen, "opening")
        return true
    }

    // Closes the open popup. With `content`, only if that popup is the open one,
    // so a late close from a popup that was already replaced is harmless.
    function close(content) {
        if (!root.anyOpen) return
        if (content && content !== root.activeContent) return
        const prev = root.activeContent, prevScreen = root.activeScreen
        root.activeScreen  = ""
        root.activeRegion  = "none"
        root.activeContent = "none"
        _enter(prev, prevScreen, "closing")
    }

    // Closes `content` if it's open on that screen, otherwise opens it there.
    function toggle(content, screenName) {
        const screen = screenName || root._focusedScreen()
        if (root.activeContent === content && root.activeScreen === screen) {
            root.close()
            return false
        }
        return root.open(content, screen)
    }
}
