import QtQuick
import Quickshell
import "../"

// ============================================================
// PopupLayer — the only file that instantiates popup windows.
//
// shell.qml creates the anchor windows and passes them in.
// To add a new popup:
//   1. Create the .qml file in src/popups/
//   2. Add its anchor window as a property here (if new)
//   3. Instantiate it below under the right section
// ============================================================

Item {
    id: root

    // ── Anchor windows (set by shell.qml) ───────────────────
    required property var topBar       // TopBar PanelWindow
    required property var leftBorder   // left Border PanelWindow
    required property var rightBorder  // right Border PanelWindow
    required property var bottomBorder // bottom Border PanelWindow

    // Popups here don't set a screen of their own; their PopupFocusGrab uses
    // this to only grab on the focused monitor's copy.
    readonly property var hostScreen: topBar.screen

    // ── Border-anchored popups ───────────────────────────────

    // Left border → center
    ArchMenu {
        anchorWindow: root.leftBorder
        hostScreen:   root.hostScreen
    }

    // Bottom border → slides up
    WallpaperPopup { hostScreen: root.hostScreen }

    // Bottom-right corner → clipboard history + emoji
    ClipboardPopup { hostScreen: root.hostScreen }

    // ── TopBar-anchored popups ───────────────────────────────

    // Right notch — audio
    AudioPopup {
        anchorWindow: root.rightBorder
    }
    QuickControl {
        anchorWindow: root.topBar
    }

    // Center notch — dashboard (expands below the center notch)
    Dashboard {
        anchorWindow: root.topBar
        hostScreen:   root.hostScreen
    }

    // Right notch
    NotificationsPopup {
        anchorWindow: root.topBar
    }

    NotificationToast {
        anchorWindow: root.rightBorder
    }

    // Screen recorder strip options — appears below center notch on hover
    ScreenRecOptionsPopup {
        anchorWindow: root.topBar
    }

    NetworkPopup { hostScreen: root.hostScreen }
}
