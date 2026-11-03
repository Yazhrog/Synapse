import Quickshell
import QtQuick
import "../"

// ShellHost — the Dynamic Surface root (#37), enabled with SYNAPSE_SURFACE=1.
//
// Per screen: a top StrutWindow reserving the bar's space, the DynamicSurface
// drawing the frame and the bar, and the centered modal windows, which stay
// separate windows. Popups aren't migrated yet (#41), so in this phase they
// don't open.
//
// Space reservation matches the legacy stack exactly: only the top reserves
// Theme.exclusionGap, scaled per screen (0 in focus mode); the side and bottom borders reserve
// nothing and Hyprland's gaps_out keeps windows clear of them. Changing that
// rule means adjusting gaps_out in config/hypr/modules/appearance.lua too.
Scope {
    id: host

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
