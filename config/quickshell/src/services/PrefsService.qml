pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../"

// ============================================================
// PrefsService — central store for shell preferences.
//
// Backed by Paths.userData("shell_prefs.json"). Bind to a pref directly
// (PrefsService.autoUpdate) and assign to change it; the file is saved
// automatically (debounced) and hot-reloaded when edited by hand.
// Missing keys keep their default, so adding a pref never breaks an
// existing file.
//
// Preferences (how the shell behaves) go here. User data (tasks, pins,
// wallpaper, keybinds) stays in its own files.
//
// Adding a pref:
//   1. add its default to `defaults`
//   2. add `property <type> <name>: root.defaults.<name>` to the adapter
//   3. add `property alias <name>: adapter.<name>` below
// ============================================================

Singleton {
    id: root

    readonly property var defaults: ({
        autoUpdate:   true,
        // Dynamic Surface scale: "off" (1.0), "auto" (screen height / 1080)
        // or a fixed factor such as "1.25". Off by default: only the frame and
        // region sizes scale yet, not the popup contents.
        surfaceScale: "off",
        // Bar: show the battery / volume % all the time instead of on hover.
        alwaysShowBatteryPercentage: false,
        alwaysShowVolumePercentage:  false,
        // Audio visualizer (cava) in the notch and the player card. Off stops
        // the cava process.
        enableVisualiser: true,
        // Config → General.
        use24HourClock:       true,
        bootFocusMode:        false,
        // Page a popup opens on when opened without one: "last" keeps the
        // page it was on, otherwise a page key.
        defaultDashboardPage: "last",
        defaultAudioPage:     "last",
        // Image for the dashboard's profile card; "" = the current wallpaper.
        avatarPath:           "",
        // Where screen recordings are saved ("~" = home).
        screenRecordingDir:   "~/Videos/screen_recordings",
        // Config → Appearance. Frame background alpha in %, blur behind the
        // frame (Hyprland layer rule in hypr/modules/rules.lua), border
        // thickness and corner radius in px (before the surface scale).
        backgroundOpacity:    100,
        backgroundBlur:       false,
        borderWidth:          6,
        cornerRadius:         17
    })

    // ── Preferences ────────────────────────────────────────────────────────
    property alias autoUpdate:   adapter.autoUpdate
    property alias surfaceScale: adapter.surfaceScale
    property alias alwaysShowBatteryPercentage: adapter.alwaysShowBatteryPercentage
    property alias alwaysShowVolumePercentage:  adapter.alwaysShowVolumePercentage
    property alias enableVisualiser:            adapter.enableVisualiser
    property alias use24HourClock:              adapter.use24HourClock
    property alias bootFocusMode:               adapter.bootFocusMode
    property alias defaultDashboardPage:        adapter.defaultDashboardPage
    property alias defaultAudioPage:            adapter.defaultAudioPage
    property alias avatarPath:                  adapter.avatarPath
    property alias screenRecordingDir:          adapter.screenRecordingDir
    property alias backgroundOpacity:           adapter.backgroundOpacity
    property alias backgroundBlur:              adapter.backgroundBlur
    property alias borderWidth:                 adapter.borderWidth
    property alias cornerRadius:                adapter.cornerRadius

    // True once the file has been read (or created). Services that act on a
    // pref at startup should wait for it.
    property bool ready: false
    signal loaded()

    function isDefault(key: string): bool {
        return adapter[key] === root.defaults[key]
    }

    function reset(key: string) {
        if (key in root.defaults)
            adapter[key] = root.defaults[key]
    }

    function resetAll() {
        for (const key in root.defaults)
            adapter[key] = root.defaults[key]
    }

    function _markReady() {
        if (root.ready) return
        root.ready = true
        root.loaded()
    }

    property FileView _file: FileView {
        path: Paths.userData("shell_prefs.json")
        watchChanges: true
        printErrors: false

        onFileChanged: reload()
        onLoaded: root._markReady()
        onLoadFailed: function(error) {
            if (error === FileViewError.FileNotFound)
                root._migrateLegacy()
            else
                console.log("PrefsService: failed to read prefs (" + FileViewError.toString(error) + "), using defaults")
            root._file.writeAdapter()
            root._markReady()
        }
        // Debounced so dragging a slider doesn't write on every tick.
        onAdapterUpdated: root._saveTimer.restart()

        JsonAdapter {
            id: adapter
            property bool   autoUpdate:   root.defaults.autoUpdate
            property string surfaceScale: root.defaults.surfaceScale
            property bool   alwaysShowBatteryPercentage: root.defaults.alwaysShowBatteryPercentage
            property bool   alwaysShowVolumePercentage:  root.defaults.alwaysShowVolumePercentage
            property bool   enableVisualiser:            root.defaults.enableVisualiser
            property bool   use24HourClock:              root.defaults.use24HourClock
            property bool   bootFocusMode:               root.defaults.bootFocusMode
            property string defaultDashboardPage:        root.defaults.defaultDashboardPage
            property string defaultAudioPage:            root.defaults.defaultAudioPage
            property string avatarPath:                  root.defaults.avatarPath
            property string screenRecordingDir:          root.defaults.screenRecordingDir
            property int    backgroundOpacity:           root.defaults.backgroundOpacity
            property bool   backgroundBlur:              root.defaults.backgroundBlur
            property int    borderWidth:                 root.defaults.borderWidth
            property int    cornerRadius:                root.defaults.cornerRadius
        }
    }

    property Timer _saveTimer: Timer {
        interval: 300
        onTriggered: root._file.writeAdapter()
    }

    // First run after the move to shell_prefs.json: carry over the
    // auto-update toggle UpdateService used to keep in update_prefs.json.
    function _migrateLegacy() {
        const raw = root._legacyUpdatePrefs.text()
        if (!raw) return
        try {
            const o = JSON.parse(raw)
            if (typeof o.autoUpdate === "boolean")
                adapter.autoUpdate = o.autoUpdate
        } catch (e) {}
    }

    property FileView _legacyUpdatePrefs: FileView {
        path: Paths.userData("update_prefs.json")
        blockAllReads: true
        printErrors: false
    }
}
