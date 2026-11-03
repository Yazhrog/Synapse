import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
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
// Theme.exclusionGap (0 in focus mode); the side and bottom borders reserve
// nothing and Hyprland's gaps_out keeps windows clear of them. Changing that
// rule means adjusting gaps_out in config/hypr/modules/appearance.lua too.
//
// Keyboard-focus spike (#38 §7):
//   SYNAPSE_SURFACE_FOCUS = exclusive (default) | ondemand | grab
//   qs ipc call surfaceSpike toggle   → test field on the focused monitor
Scope {
    id: host

    readonly property string focusMode: {
        const m = Quickshell.env("SYNAPSE_SURFACE_FOCUS")
        return (m === "ondemand" || m === "grab") ? m : "exclusive"
    }

    property bool   spikeOpen:   false
    property string spikeScreen: ""

    IpcHandler {
        target: "surfaceSpike"
        function toggle(): void {
            if (!host.spikeOpen)
                host.spikeScreen = Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : ""
            host.spikeOpen = !host.spikeOpen
            console.log("FocusSpike: open=" + host.spikeOpen + " screen=" + host.spikeScreen + " mode=" + host.focusMode)
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
                    reserve: ShellState.focusMode ? 0 : Theme.exclusionGap
                }

                DynamicSurface {
                    screen:    modelData
                    focusMode: host.focusMode
                    spikeOpen: host.spikeOpen
                               && (host.spikeScreen === "" || host.spikeScreen === modelData.name)
                    onSpikeCloseRequested: host.spikeOpen = false
                }

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
