import QtQuick

// FontTokens — Theme.font (ARCHITECTURE.md §5.12): families, the size scale
// and weights, with today's values. Views still use literal sizes; they move
// to these tokens in v0.8.0's per-area passes (decision D1), the families
// with the font set (#104), the scale with content scaling (#79).
//
// Instantiated by Theme only.
QtObject {
    // ── Families ─────────────────────────────────────────────────────────────
    readonly property string ui:   Qt.application.font.family   // what a Text gets by default
    readonly property string mono: "monospace"
    readonly property string icon: "JetBrainsMono Nerd Font"      // Nerd Font glyphs

    // ── Sizes (px) ───────────────────────────────────────────────────────────
    readonly property int caption:   9
    readonly property int small:     10
    readonly property int body:      11
    readonly property int bodyLarge: 12
    readonly property int title:     13
    readonly property int heading:   15
    readonly property int display:   32

    // ── Weights ──────────────────────────────────────────────────────────────
    readonly property int regular:  Font.Normal
    readonly property int medium:   Font.Medium
    readonly property int semibold: Font.DemiBold
    readonly property int bold:     Font.Bold
}
