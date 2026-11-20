import QtQuick

// MotionTokens — Theme.motion (ARCHITECTURE.md §5.12): durations (ms) and
// easing curves. `slow` is the frame's open/close animation (the popup
// lifecycle times its phases with it), `fast` the fade of region contents.
// The animation engine (F3d) scales these from its speed and style prefs.
// Use them through the Anim and Fade components (theme/).
//
// Instantiated by Theme only.
QtObject {
    // ── Durations ────────────────────────────────────────────────────────────
    readonly property int instant: 80
    readonly property int fast:    150
    readonly property int normal:  200
    readonly property int slow:    320

    // ── Curves (Easing.Type) ─────────────────────────────────────────────────
    readonly property int standard:   Easing.OutCubic     // something arrives or responds
    readonly property int emphasized: Easing.InOutCubic   // something grows or moves across
    readonly property int overshoot:  Easing.OutBack      // a playful settle
}
