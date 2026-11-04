import Quickshell
import Quickshell.Hyprland
import QtQuick
import "../"

// ShellHost — the shell root: one Dynamic Surface per screen (#37).
//
// Per screen: a top StrutWindow reserving the bar's space, the DynamicSurface
// drawing the frame, the bar and every popup, and the centered modal windows,
// which stay separate windows.
//
// Space reservation: the top reserves Theme.exclusionGap, scaled per screen
// (0 in focus mode). At the default border width the side and bottom borders
// reserve nothing and Hyprland's gaps_out keeps windows clear of them; a wider
// border (Config → Appearance) reserves the extra width on those edges.
// Changing that rule means adjusting gaps_out in
// config/hypr/modules/appearance.lua too.
Scope {
    id: host

    // Switching workspace or monitor, or a new window opening, closes the
    // open popup.
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "workspace" || event.name === "activemonitor"
                    || event.name === "activespecial" || event.name === "openwindow")
                Popups.closeAll()
        }
    }

    Variants {
        model: Quickshell.screens

        delegate: Component {
            Scope {
                required property var modelData

                StrutWindow {
                    screen:  modelData
                    edge:    "top"
                    reserve: ShellState.focusMode ? 0 : Math.round(Theme.exclusionGap * SurfaceState.scaleFor(modelData))
                }

                // Border wider than the default: reserve the difference on
                // the sides and bottom (none at the default, as before).
                readonly property int _extraBorder: PrefsService.barStyle !== "frame" ? 0 : Math.max(0, Math.round(
                    (Theme.borderWidth - PrefsService.defaults.borderWidth) * SurfaceState.scaleFor(modelData)))

                LazyLoader {
                    active: _extraBorder > 0
                    StrutWindow { screen: modelData; edge: "left";   reserve: _extraBorder }
                }
                LazyLoader {
                    active: _extraBorder > 0
                    StrutWindow { screen: modelData; edge: "right";  reserve: _extraBorder }
                }
                LazyLoader {
                    active: _extraBorder > 0
                    StrutWindow { screen: modelData; edge: "bottom"; reserve: _extraBorder }
                }

                DynamicSurface { screen: modelData }

                // GPU mode change confirmation modal
                ConfirmDialog { screen: modelData }

                // Critical battery — blocking, must be acknowledged
                BatteryCriticalDialog { screen: modelData }

                // Shell update notification
                UpdatePopup { screen: modelData }
            }
        }
    }
}
