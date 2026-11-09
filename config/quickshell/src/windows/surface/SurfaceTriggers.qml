import QtQuick
import "../../"
import "../../theme/"

// SurfaceTriggers — the border trigger zones of a DynamicSurface (#42).
//
// Each zone is Metrics.edgeTriggerDepth deep (Hyprland's gaps_out), so it's
// easy to hit at the screen edge without covering windows, and at least as
// deep as the border:
//   • right border middle — hovering shows the Quick Controls OSD
//   • bottom border centre — tap toggles the wallpaper picker
//   • bottom-right corner  — tap toggles the clipboard
// The OSD opens at once on the trigger and closes Popups.hoverCloseDelay
// after neither the trigger nor the OSD (`osdHovered`) is hovered.

Item {
    id: triggers

    // The DynamicSurface: size, border, px(), screen
    required property var surface
    // The OSD itself is hovered
    property bool osdHovered: false

    // True while the hover on the right trigger keeps the OSD open
    readonly property bool quickHoverOpen: _quickHoverOpen

    // The zones, for the surface's input mask
    readonly property Item rightZone:  rightTrigger
    readonly property Item bottomZone: bottomTrigger
    readonly property Item cornerZone: cornerTrigger

    readonly property int _depth: Math.max(surface.px(Metrics.edgeTriggerDepth), surface.borderWidth)

    Item {
        id: rightTrigger
        x: triggers.surface.width - width; y: (triggers.surface.height - height) / 2
        width: triggers._depth; height: triggers.surface.px(Metrics.sideTriggerLength)
        HoverHandler { id: rightTriggerHover }
    }

    Item {
        id: bottomTrigger
        x: (triggers.surface.width - width) / 2; y: triggers.surface.height - height
        width: triggers.surface.px(Metrics.bottomTriggerWidth); height: triggers._depth
        TapHandler { onTapped: Popups.toggle("wallpaper", triggers.surface.screenName) }
    }

    Item {
        id: cornerTrigger
        x: triggers.surface.width - width; y: triggers.surface.height - height
        width: triggers.surface.px(Metrics.cornerTriggerWidth); height: triggers._depth
        TapHandler { onTapped: Popups.toggle("clipboard", triggers.surface.screenName) }
    }

    property bool _quickHoverOpen: false
    readonly property bool _quickHovered: rightTriggerHover.hovered || osdHovered
    on_QuickHoveredChanged: {
        if (_quickHovered) {
            closeTimer.stop()
            if (rightTriggerHover.hovered) _quickHoverOpen = true
        } else if (_quickHoverOpen) {
            closeTimer.restart()
        }
    }
    Timer {
        id: closeTimer
        interval: Popups.hoverCloseDelay
        onTriggered: if (!triggers._quickHovered) triggers._quickHoverOpen = false
    }
}
