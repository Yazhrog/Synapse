import QtQuick
import "../../"
import "../../theme/"
import "../../modules/Center/"
import "../../modules/Right/"
import "../../modules/Left/"

// SurfaceBar — the three notch contents of the bar (left, centre, right),
// placed in the notches DynamicSurface draws. Fades out in focus mode; in
// pills the contents are centred in the floating capsules.

Item {
    id: bar

    // The DynamicSurface: notch sizes, style, open region, scale
    required property var surface

    // DynamicSurface sizes the notches from these
    readonly property real leftContentWidth:   leftContent.implicitWidth
    readonly property real centerContentWidth: centerContent.implicitWidth
    readonly property real rightContentWidth:  rightContent.implicitWidth

    opacity: ShellState.focusMode ? 0 : 1
    Behavior on opacity { NumberAnimation { duration: Theme.animDuration; easing.type: Easing.InOutCubic } }

    // In pills the capsules start one gap from the edges: center the
    // contents in them.
    readonly property real _pillShift: surface.pills ? surface.borderWidth / 2 : 0

    Item {
        id: leftNotch
        x: bar._pillShift; y: bar._pillShift
        width:  bar.surface.lWidth
        height: bar.surface.notchHeight

        LeftContent {
            id: leftContent
            localScale: bar.surface.localScale
            anchors.centerIn: parent
        }
    }

    Item {
        id: centerNotch
        x: (bar.surface.width - bar.surface.cWidth) / 2; y: bar._pillShift
        width:  bar.surface.cWidth
        height: bar.surface.notchHeight

        CenterContent {
            id: centerContent
            localScale: bar.surface.localScale
            anchors.centerIn: parent
            // The dashboard covers the notch while open.
            opacity: bar.surface.openRegion === "top" ? 0 : 1
            Behavior on opacity { NumberAnimation { duration: Metrics.regionFadeDuration } }
        }
    }

    Item {
        id: rightNotch
        x: bar.surface.width - bar.surface.rWidth - bar._pillShift; y: bar._pillShift
        width:  bar.surface.rWidth
        height: bar.surface.notchHeight
        clip:   true

        RightContent {
            id: rightContent
            localScale: bar.surface.localScale
            anchors.right:          parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.rightMargin:    bar.surface.notchPadding
        }
    }
}
