import QtQuick
import qs.src.state
import qs.src.theme
// SurfaceBar — the bar's three zones (left, centre, right), placed in the
// notches DynamicSurface draws. The widgets come from
// features/bar/BarWidgets.qml (handed down as `widgets`); each zone is a
// BarZone. Fades out in focus mode; in pills the contents are centred in the
// floating capsules.

Item {
    id: bar

    // The DynamicSurface: notch sizes, style, open region, scale
    required property var surface
    // BarWidgetSpec list (features/bar/BarWidgets.qml)
    property var widgets: []

    // DynamicSurface sizes the notches from these
    readonly property real leftContentWidth:   leftContent.implicitWidth
    // The centre notch is as wide as its popup or its minimum width: its
    // widgets size themselves to it.
    readonly property real centerContentWidth: 0
    readonly property real rightContentWidth:  rightContent.implicitWidth

    opacity: ShellModes.focusMode ? 0 : 1
    Behavior on opacity { NumberAnimation { duration: Theme.motion.slow; easing.type: Easing.InOutCubic } }

    // In pills the capsules start one gap from the edges: center the
    // contents in them.
    readonly property real _pillShift: surface.pills ? surface.borderWidth / 2 : 0

    Item {
        id: leftNotch
        x: bar._pillShift; y: bar._pillShift
        width:  bar.surface.lWidth
        height: bar.surface.notchHeight

        BarZone {
            id: leftContent
            zone:       "left"
            widgets:    bar.widgets
            spacing:    5
            localScale: bar.surface.localScale
            anchors.centerIn: parent
        }
    }

    Item {
        id: centerNotch
        x: (bar.surface.width - bar.surface.cWidth) / 2; y: bar._pillShift
        width:  bar.surface.cWidth
        height: bar.surface.notchHeight

        BarZone {
            id: centerContent
            zone:       "center"
            widgets:    bar.widgets
            localScale: bar.surface.localScale
            anchors.centerIn: parent
            // The dashboard covers the notch while open.
            opacity: bar.surface.openRegion === "top" ? 0 : 1
            Behavior on opacity { Fade {} }
        }
    }

    Item {
        id: rightNotch
        x: bar.surface.width - bar.surface.rWidth - bar._pillShift; y: bar._pillShift
        width:  bar.surface.rWidth
        height: bar.surface.notchHeight
        clip:   true

        BarZone {
            id: rightContent
            zone:       "right"
            widgets:    bar.widgets
            spacing:    6
            localScale: bar.surface.localScale
            anchors.right:          parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.rightMargin:    bar.surface.notchPadding

            // The right notch grows for notifications and network: its
            // widgets fade out meanwhile.
            opacity: (Popups.notificationsOpen || Popups.networkOpen) ? 0 : 1
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: 150 } }
        }
    }
}
