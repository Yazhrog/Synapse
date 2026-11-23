import QtQuick
import qs.src.theme.sources

// ColorTokens — Theme.color (ARCHITECTURE.md §5.12). Roles come from the
// colour source; state layers are the foreground with a fixed alpha, so a
// light palette (F17) needs no view change.
//
// Instantiated by Theme only; `frameOpacity` is Theme.frame.opacity.
QtObject {
    id: root

    property ColorSource source: MatugenSource {}
    property real frameOpacity: 1

    // ── Roles ────────────────────────────────────────────────────────────────
    readonly property color background:    source.background
    // The frame fill (bar, borders, popups): background × Config → Appearance opacity.
    readonly property color surface:       Qt.rgba(background.r, background.g, background.b,
                                                   background.a * frameOpacity)
    readonly property color surfaceRaised: alpha(text, 0.05)     // cards inside a popup
    readonly property color accent:        source.accent
    readonly property color text:          source.text
    readonly property color textMuted:     source.textMuted
    readonly property color border:        source.border
    readonly property color danger:        "#f87171"
    readonly property color warning:       "#f5c47a"
    readonly property color success:       "#a6e3a1"
    // See ColorSource.iconFont.
    readonly property color iconFont:      source.iconFont

    // ── State layers (foreground × alpha) ────────────────────────────────────
    readonly property color hairline:    alpha(text, 0.07)   // separators, card outlines
    readonly property color fillSubtle:  alpha(text, 0.04)   // resting card / row fill
    readonly property color fillHover:   alpha(text, 0.08)
    readonly property color fillPressed: alpha(text, 0.12)
    // Behind a modal. Not a state layer: it dims whatever the palette, so it is
    // a fixed black (the views' "#99000000"), neither foreground nor background.
    readonly property color scrim:       Qt.rgba(0, 0, 0, 0.6)

    // ── Workspace indicator ──────────────────────────────────────────────────
    readonly property color wsBackground: "#20000000"
    readonly property color wsActive:     "#FFFFFF"
    readonly property color wsOccupied:   "#80FFFFFF"
    readonly property color wsEmpty:      "#30FFFFFF"
    readonly property color wsOverlay:    "#CC1e1e2e"
    readonly property color wsUrgent:     "#fa6b94"

    function alpha(c: color, a: real): color {
        return Qt.rgba(c.r, c.g, c.b, a)
    }
}
