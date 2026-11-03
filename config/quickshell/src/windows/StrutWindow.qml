import Quickshell
import Quickshell.Wayland
import QtQuick
import "../"

// StrutWindow — an invisible window whose only job is to reserve space
// (an exclusive zone) along one screen edge, so tiled windows stay clear of
// the frame. The DynamicSurface itself is fullscreen and ignores exclusive
// zones: a layer surface can only reserve space along one edge.
//
// Takes no input (empty mask) and draws nothing.
PanelWindow {
    id: root

    property string edge:    "top"   // top | bottom | left | right
    property int    reserve: 0       // reserved thickness in px

    readonly property bool _horizontal: edge === "top" || edge === "bottom"

    anchors {
        top:    edge !== "bottom"
        bottom: edge !== "top"
        left:   edge !== "right"
        right:  edge !== "left"
    }

    implicitHeight: _horizontal ? 1 : 0
    implicitWidth:  _horizontal ? 0 : 1

    color:         "transparent"
    mask:          Region {}
    // Set directly, not animated: every change makes Hyprland re-tile.
    exclusiveZone: reserve

    WlrLayershell.layer:     WlrLayer.Bottom
    WlrLayershell.namespace: "synapse-strut-" + edge
}
