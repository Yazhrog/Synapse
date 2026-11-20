import QtQuick
import qs.src.services.data

// FrameTokens — Theme.frame (ARCHITECTURE.md §5.12): the frame, notch and
// region sizes of the Dynamic Surface, unscaled (the surface multiplies them
// by its localScale), plus the frame prefs. The corner and notch radii are
// Theme.radius.card / .notch, the durations Theme.motion.
//
// Instantiated by Theme only.
QtObject {
    // -- Frame prefs (Config → Appearance) --
    // Border width and background opacity are user prefs; defaults 6 px, 100 %.
    readonly property int  borderWidth: Prefs.data.borderWidth
    readonly property real opacity:     Prefs.data.backgroundOpacity / 100
    // Bar style pref ("frame", "bar" or "pills"; PrefSchema rejects anything else).
    readonly property string barStyle:  Prefs.data.barStyle

    // -- Bar Sizes --
    // Pills bar style: gap between the pills/cards and the screen edges.
    readonly property int pillGap:       6
    readonly property int notchHeight:   40
    readonly property int exclusionGap:  34
    readonly property int spacing:       10

    // -- Notch Content Padding --
    // Space added around the content inside each notch
    readonly property int notchPadding:           16   // horizontal padding each side
    readonly property int notchHorizontalPadding: 20
    readonly property int notchVerticalPadding:   10
    readonly property int notchSideMargin:        10

    // -- Notch Width Constraints --
    // Each notch sizes itself to its content, clamped between min and max.
    readonly property int lNotchMinWidth: 180
    readonly property int lNotchMaxWidth: 360

    readonly property int cNotchMinWidth: 300
    readonly property int cNotchMaxWidth: 360

    readonly property int rNotchMinWidth: 200
    readonly property int rNotchMaxWidth: 360

    // -- Dashboard Dimensions --
    // Target size the center notch expands to when the dashboard is open.
    readonly property int dashboardWidth:  900
    readonly property int dashboardHeight: 520

    // -- Notifications Popup Width --
    readonly property int notificationsWidth: 400
    readonly property int notificationToastWidth: notificationsWidth - 20
    readonly property int networkPopupWidth:  480

    // -- Popup Size Constraints --
    readonly property int popupMinWidth:   160
    readonly property int popupMaxWidth:   420
    readonly property int popupMinHeight:   80
    readonly property int popupMaxHeight:  520
    readonly property int popupPadding:     16

    // -- Workspace Dot Sizes --
    readonly property int wsDotSize:     10
    readonly property int wsActiveWidth: 24
    readonly property int wsSpacing:     6
    readonly property int wsPadding:     8
    readonly property int wsRadius:      16

    // -- Dynamic Surface regions (#37) --
    // Unscaled sizes, multiplied by the surface's localScale. "Body" sizes
    // exclude the flares that melt a region into the frame.
    readonly property int powerMenuWidth:        216   // content area of the power menu
    readonly property int powerMenuHeight:       258
    readonly property int powerMenuPadding:      6     // around it, inside the left-center bump
    readonly property int sideRegionHeight:      306   // audio popup and OSD (right-center)
    readonly property int osdWidth:              180
    readonly property int osdTopPadding:         30
    readonly property int networkPopupBodyWidth: 489   // networkPopupWidth + its inner margin
    readonly property int networkPopupHeight:    648   // incl. the bottom flare (notchRadius)
    readonly property int wallpaperPanelWidth:   980
    readonly property int wallpaperPanelHeight:  420
    readonly property int clipboardPanelWidth:   420
    readonly property int clipboardPanelHeight:  560
    readonly property int toastNotchExtra:       13    // toast notch = toast width + notchRadius + this
    readonly property int sideTriggerLength:     300   // hover zones in the middle of the side borders
    readonly property int bottomTriggerWidth:    420   // tap zone in the middle of the bottom border
    readonly property int cornerTriggerWidth:    80    // tap zone in the bottom-right corner
    readonly property int edgeTriggerDepth:      12    // depth of those zones; = gaps_out, so they stay off windows

    // -- Settings widgets (components/settings/Settings*.qml) --
    readonly property int settingsRowMinHeight: 44
    readonly property int settingsRowPadding:   14
}
