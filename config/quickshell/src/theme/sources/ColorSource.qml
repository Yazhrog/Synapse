import QtQuick

// ColorSource — where the palette comes from (ARCHITECTURE.md §5.11, colour
// source strategy). `ColorTokens` reads these base colours and derives every
// role and state layer from them, so a new source (a preset, F3a; a user
// override, F3b) only has to fill these properties.
//
// The values here are the fallback palette, used until a source has loaded.
// Implementations: MatugenSource (colors.json written by matugen).
QtObject {
    property color background: "#1a282a"
    property color accent:     "#a6d0f7"
    property color text:       "#cdd6f4"
    property color textMuted:  "#94e2d5"
    property color border:     "#ffffff"
    // A colour today, though NotificationList uses it as a font family
    // (ARCHITECTURE.md F-4, fixed with the font set in #104).
    property color iconFont:   "#2f8d97"
}
