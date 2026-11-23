pragma Singleton
import QtQuick
import Quickshell
// PrefSchema — every shell preference: its default, type, allowed values and
// the label and description its config control shows (ARCHITECTURE.md §10.5).
//
//   myPref: { default: true, type: "bool", label: "My pref", description: "…" }
//
// type        "bool", "int", "real", "string" or "object"
// min / max   numbers are clamped to them
// options     [{ value, label }] for a dropdown; with `strict: true` any other
//             value is replaced by the default (e.g. barStyle)
// Prefs validates every value it reads or writes against this; the config
// controls (features/dashboard/config/controls/Pref*.qml) take their label,
// description, range and options from it.
Singleton {
    readonly property var keys: ({
        autoUpdate: {
            default: true, type: "bool",
            label: "Check for updates on startup",
            description: "Looks for new commits on origin/main 30s after login."
        },
        // Dynamic Surface scale: "off" (1.0), "auto" (screen height / 1080) or
        // a fixed factor such as "1.25". Off by default: only the frame and
        // region sizes scale yet, not the popup contents.
        surfaceScale: {
            default: "off", type: "string",
            label: "Surface scale",
            description: "Scales the frame and popup sizes. Popup contents don't scale yet.",
            options: [{ value: "off", label: "Off" }, { value: "auto", label: "Auto" },
                      { value: "1.25", label: "125%" }, { value: "1.5", label: "150%" }]
        },
        // Bar: show the battery / volume % all the time instead of on hover.
        alwaysShowBatteryPercentage: {
            default: false, type: "bool",
            label: "Always show battery percentage",
            description: "Otherwise it shows when you hover the icon."
        },
        alwaysShowVolumePercentage: {
            default: false, type: "bool",
            label: "Always show volume percentage",
            description: "Otherwise it shows when you hover the icon."
        },
        // Audio visualizer (cava) in the notch and the player card. Off stops
        // the cava process.
        enableVisualiser: {
            default: true, type: "bool",
            label: "Audio visualizer",
            description: "Bars in the notch and the player card. Off stops cava."
        },
        use24HourClock: {
            default: true, type: "bool",
            label: "Use 24-hour time",
            description: "Off shows the bar and dashboard clocks as 3:45 PM."
        },
        bootFocusMode: {
            default: false, type: "bool",
            label: "Boot into Focus Mode",
            description: "Hides the bar and tightens the gaps when the shell starts."
        },
        // Page a popup opens on when opened without one: "last" keeps the
        // page it was on, otherwise a page key (the options come from the
        // popup's page registry).
        defaultDashboardPage: {
            default: "last", type: "string",
            label: "Default dashboard tab",
            description: "Shown when the dashboard opens from the bar."
        },
        defaultAudioPage: {
            default: "last", type: "string",
            label: "Default audio tab",
            description: "Shown when the audio popup opens from the bar."
        },
        // Image for the dashboard's profile card; "" = the current wallpaper.
        avatarPath: {
            default: "", type: "string",
            label: "Custom avatar",
            description: "Image for the dashboard's profile card. Empty uses the wallpaper."
        },
        // Where screen recordings are saved ("~" = home).
        screenRecordingDir: {
            default: "~/Videos/screen_recordings", type: "string",
            label: "Screen recording folder",
            description: "Where new recordings are saved."
        },
        // Frame background alpha in %, blur behind the frame (Hyprland layer
        // rule in hypr/modules/rules.lua), border thickness and corner radius
        // in px (before the surface scale).
        backgroundOpacity: {
            default: 100, type: "int", min: 50, max: 100,
            label: "Background opacity",
            description: "Of the bar, the borders and the popups."
        },
        backgroundBlur: {
            default: false, type: "bool",
            label: "Background blur"
        },
        borderWidth: {
            default: 6, type: "int", min: 0, max: 16,
            label: "Border width"
        },
        cornerRadius: {
            default: 17, type: "int", min: 0, max: 30,
            label: "Corner roundness",
            description: "Frame corners, notches, popups and cards."
        },
        // "frame" (notches joined by the borders), "bar" (full-width top bar,
        // no borders) or "pills" (floating capsules).
        barStyle: {
            default: "frame", type: "string", strict: true,
            label: "Bar style",
            options: [{ value: "frame", label: "Frame" }, { value: "bar", label: "Bar" },
                      { value: "pills", label: "Pills" }]
        },
        // Bar widget order per zone, { left: [keys], center: [keys], right:
        // [keys] } (features/bar/BarWidgets.qml keys). A zone that isn't
        // listed shows every widget of the zone in its default order; the
        // layout picker comes with #23.
        barLayout: {
            default: ({}), type: "object",
            label: "Bar layout"
        }
    })

    // { key: default } for every pref.
    readonly property var defaults: {
        const d = {}
        for (const k in keys) d[k] = keys[k].default
        return d
    }

    // `v` checked against the pref's schema: the right type, clamped to
    // min/max, one of `options` when strict; otherwise the default.
    function validate(key: string, v: var): var {
        const s = keys[key]
        if (!s) return v
        switch (s.type) {
        case "bool":
            return typeof v === "boolean" ? v : s.default
        case "int":
        case "real": {
            let n = typeof v === "number" ? v : Number(v)
            if (typeof v === "boolean" || v === "" || v === null || !isFinite(n)) return s.default
            if (s.type === "int") n = Math.round(n)
            if (s.min !== undefined) n = Math.max(s.min, n)
            if (s.max !== undefined) n = Math.min(s.max, n)
            return n
        }
        case "string":
            if (typeof v !== "string") return s.default
            if (s.strict && s.options && !s.options.some(o => o.value === v)) return s.default
            return v
        case "object":
            return v !== null && typeof v === "object" && !Array.isArray(v) ? v : s.default
        }
        return v
    }
}
