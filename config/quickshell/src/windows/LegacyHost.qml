import Quickshell
import QtQuick
import "../popups"
import "../"

// LegacyHost — today's window stack, one set per screen: TopBar, three
// Border windows, the overlays and PopupLayer. Used while SYNAPSE_SURFACE is
// off; replaced by ShellHost once the Dynamic Surface is the default (#43).
Scope {
    Variants {
        model: Quickshell.screens

        delegate: Component {
            Scope {
                required property var modelData

                // ── Windows ──────────────────────────────────────
                TopBar    { id: topBar;        screen: modelData }

                Border    { id: leftBorder;    screen: modelData; edge: "left"   }
                Border    { id: rightBorder;   screen: modelData; edge: "right"  }
                Border    { id: bottomBorder;  screen: modelData; edge: "bottom" }

                // ── Overlays ─────────────────────────────────────
                // Dismisses all popups on click-outside or Escape
                PopupDismiss { screen: modelData }

                // GPU mode change confirmation modal
                ConfirmDialog { screen: modelData }

                // Critical battery — blocking, must be acknowledged
                BatteryCriticalDialog { screen: modelData }

                // Shell update notification
                UpdatePopup { screen: modelData }

                // ── All popups ───────────────────────────────────
                // Add new popups in src/popups/PopupLayer.qml only
                PopupLayer {
                    topBar:       topBar
                    leftBorder:   leftBorder
                    rightBorder:  rightBorder
                    bottomBorder: bottomBorder
                }
            }
        }
    }
}
