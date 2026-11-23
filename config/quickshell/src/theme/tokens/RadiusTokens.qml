import QtQuick
import qs.src.services.data

// RadiusTokens — Theme.radius (ARCHITECTURE.md §5.12). `card` is the corner
// radius pref (Config → Appearance, default 17 px): the frame's corners and
// the cards that follow them. `notch` (the top notches, the popups grown
// from them and their flares) follows it in proportion: 15 px at 17 px.
//
// Instantiated by Theme only.
QtObject {
    readonly property int sm:    4
    readonly property int md:    6
    readonly property int lg:    8
    readonly property int card:  Prefs.data.cornerRadius
    readonly property int notch: Math.round(card * 15 / 17)
}
