pragma Singleton
import QtQuick

QtObject {
    // --Bar Toggle--
    property bool barEnabled: false

    // -- Bar Sizes --
    property int borderWidth:   6
    property int cornerRadius:  17
    property int notchRadius:   15
    property int notchHeight:   40
    property int exclusionGap:  34
    property int spacing:       10

    // -- Notch Content Padding --
    // Space added around the content inside each notch
    property int notchPadding:           16   // horizontal padding each side
    property int notchHorizontalPadding: 20
    property int notchVerticalPadding:   10
    property int notchSideMargin:        10

    // -- Notch Width Constraints --
    // Each notch sizes itself to its content, clamped between min and max.
    property int lNotchMinWidth: 180
    property int lNotchMaxWidth: 360

    property int cNotchMinWidth: 300
    property int cNotchMaxWidth: 360

    property int rNotchMinWidth: 200
    property int rNotchMaxWidth: 360

    // -- Dashboard Dimensions --
    // Target size the center notch expands to when the dashboard is open.
    property int dashboardWidth:  900
    property int dashboardHeight: 520

    // -- Notifications Popup Width --
    property int notificationsWidth: 400
    property int notificationToastWidth: notificationsWidth - 20
    property int networkPopupWidth:  480

    // -- Popup Size Constraints --
    property int popupMinWidth:   160
    property int popupMaxWidth:   420
    property int popupMinHeight:   80
    property int popupMaxHeight:  520
    property int popupPadding:     16

    // -- Workspace Dot Sizes --
    property int wsDotSize:     10
    property int wsActiveWidth: 24
    property int wsSpacing:     6
    property int wsPadding:     8
    property int wsRadius:      16

    // -- Animations --
    property int animDuration: 320

    // -- Dynamic Surface regions (#37) --
    // Unscaled sizes, multiplied by the surface's localScale. "Body" sizes
    // exclude the flares that melt a region into the frame.
    property int powerMenuWidth:        216   // content area of the power menu
    property int powerMenuHeight:       258
    property int powerMenuPadding:      6     // around it, inside the left-center bump
    property int sideRegionHeight:      306   // audio popup and OSD (right-center)
    property var audioPageWidths:       ({ output: 200, input: 200, mixer: 300 })
    property int osdWidth:              180
    property int osdTopPadding:         30
    property int networkPopupBodyWidth: 489   // networkPopupWidth + its inner margin
    property int networkPopupHeight:    648   // incl. the bottom flare (notchRadius)
    property int wallpaperPanelWidth:   980
    property int wallpaperPanelHeight:  420
    property int clipboardPanelWidth:   420
    property int clipboardPanelHeight:  560
    property int toastNotchExtra:       13    // toast notch = toast width + notchRadius + this
    property int regionFadeDuration:    150
    property int sideTriggerLength:     300   // hover zones in the middle of the side borders
    property int bottomTriggerWidth:    420   // tap zone in the middle of the bottom border
    property int cornerTriggerWidth:    80    // tap zone in the bottom-right corner

    // -- Settings widgets (components/Settings*.qml) --
    property int settingsRowMinHeight: 44
    property int settingsRowPadding:   14
}
