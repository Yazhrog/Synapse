pragma Singleton
import QtQuick
import Quickshell
import qs.src.theme.tokens

// Theme — the facade over the design tokens (ARCHITECTURE.md §5.9, §5.12),
// the one theme import a view needs:
//
//   Theme.color   roles (accent, text, surface…), state layers, alpha(c, a)
//   Theme.font    families, size scale, weights
//   Theme.space   spacing scale
//   Theme.radius  sm/md/lg, card (corner pref), notch
//   Theme.motion  durations and curves (with the Anim / Fade components)
//   Theme.frame   frame and region sizes, frame prefs
//
// The colours come from a ColorSource (theme/sources/; matugen today).
Singleton {
    id: root

    readonly property FrameTokens  frame:  FrameTokens {}
    readonly property ColorTokens  color:  ColorTokens { frameOpacity: root.frame.opacity }
    readonly property FontTokens   font:   FontTokens {}
    readonly property SpaceTokens  space:  SpaceTokens {}
    readonly property RadiusTokens radius: RadiusTokens {}
    readonly property MotionTokens motion: MotionTokens {}
}
