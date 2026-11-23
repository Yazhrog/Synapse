import QtQuick
import Quickshell
import qs.src.services.desktop
// ─── LayoutIndicator ────────────────────────────────────────────────────────
// Small icon button beside the Workspaces module.
// Shows the active tiling layout for the focused workspace.
//
// Layout → symbol map:
//   dwindle  →       (nf-md-view_quilt)
//   master   →       (nf-md-view_split_vertical)
//   monocle  → 󰊓     (nf-md-fullscreen)
//   scroller → 󰔧     (nf-md-scroll_horizontal)
//
// KeyboardLayoutService reads the layout (on Hyprland events and every 4 s)
// and switches it: left click next, right click previous.
// ────────────────────────────────────────────────────────────────────────────

Item {
    id: root

    implicitWidth:  26
    implicitHeight: 26

    // ── State (KeyboardLayoutService) ─────────────────────────────────────────

    readonly property string currentLayout: KeyboardLayoutService.layout
    readonly property string numWindows:    KeyboardLayoutService.numWindows

    // ── Symbol map ───────────────────────────────────────────────────────────

    function layoutSymbol(name) {
        switch (name.toLowerCase()) {
            case "dwindle":  return "><"   // nf-md-view_quilt
            case "master":   return "M"   // nf-md-view_split_vertical
            case "monocle":  return "|"+root.numWindows+"|"  // nf-md-fullscreen
            case "scrolling": return "<"+root.numWindows+">"  // nf-md-scroll_horizontal (hyprscroller)
            default:         return "Unknown"  // nf-md-view_dashboard (unknown fallback)
        }
    }

    function cycleLayout(step) { KeyboardLayoutService.cycle(step) }

    // ── Visual ───────────────────────────────────────────────────────────────

    Rectangle {
        id: bg
        anchors.fill: parent
        radius: 6
        color: mouseArea.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent"

        Behavior on color {
            ColorAnimation { duration: 120 }
        }

        MouseArea {
            id: mouseArea
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            
            onClicked: (mouse) => {
                if (mouse.button === Qt.LeftButton) {
                    cycleLayout(1)  // Forward
                } else if (mouse.button === Qt.RightButton) {
                    cycleLayout(-1) // Backward
                }
            }
        }

        Text {
            id: icon
            anchors.centerIn: parent
            text: root.currentLayout !== "" ? layoutSymbol(root.currentLayout) : "…"
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 14
            color: "#cdd6f4"

            // Brief scale-pop on symbol change
            Behavior on text {
                SequentialAnimation {
                    NumberAnimation {
                        target: icon; property: "scale"
                        to: 0.6; duration: 80
                        easing.type: Easing.InQuad
                    }
                    NumberAnimation {
                        target: icon; property: "scale"
                        to: 1.0; duration: 120
                        easing.type: Easing.OutBack
                    }
                }
            }
        }
    }
}
