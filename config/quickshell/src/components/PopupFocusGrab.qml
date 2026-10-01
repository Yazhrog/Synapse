import QtQuick
import Quickshell.Hyprland

// PopupFocusGrab — the one way a popup should take keyboard focus.
//
// Wraps a Hyprland-native HyprlandFocusGrab. wlr-layer-shell's Exclusive /
// OnDemand modes aren't reliable for this: Hyprland sometimes doesn't hand a
// newly-mapped exclusive layer surface real keyboard focus until the pointer
// moves (hyprwm/Hyprland discussion #13116), and xdg-popups never pick it up
// on their own. A focus grab tells the compositor directly, for both kinds.
//
// Usage:
//   PopupFocusGrab {
//       window:       root
//       screen:       root.hostScreen       // PopupLayer popups; omit for windows with their own screen
//       active:       Popups.fooOpen
//       onFocused:    searchInput.forceActiveFocus()
//       onDismissed:  Popups.fooOpen = false
//   }
//
// Behaviour worth knowing:
//   - Activation is delayed a tick after `active` goes true: requesting the
//     grab in the same frame the surface is mapped gets rejected (surface not
//     committed yet), which fires `cleared` immediately. A `cleared` arriving
//     within the settle window is therefore treated as a rejection and retried,
//     not as the user dismissing the popup.
//   - Only the popup window itself is whitelisted. Hyprland keeps the grab's
//     surfaces in an unordered map and gives keyboard focus to whichever comes
//     first, so whitelisting the bar windows too sent the keyboard to a bar.
//   - While the grab is live the pointer can't reach other surfaces, and a
//     click outside clears the grab without being delivered — so PopupDismiss
//     never sees it. That click is reported via `dismissed()`.
//     Set dismissOnClear: false for modal dialogs that must not close that way.
//   - Popups are instantiated once per screen and all copies open together;
//     only the copy on the focused monitor grabs, otherwise each new grab
//     would clear the previous one and bounce the popup closed.

Item {
    id: root

    required property var window
    property var  screen:         window ? window.screen : null
    property bool active:         false
    property bool dismissOnClear: true

    signal focused()
    signal dismissed()

    readonly property bool _onFocusedMonitor: !screen || !Hyprland.focusedMonitor
        || screen.name === Hyprland.focusedMonitor.name

    readonly property bool _want: active && _onFocusedMonitor

    property int _retries: 0

    HyprlandFocusGrab {
        id: grab
        windows: [root.window]

        onCleared: {
            if (!root._want) return
            if (settleTimer.running && root._retries < 3) {
                root._retries++
                activateTimer.restart()
                return
            }
            if (root.dismissOnClear) root.dismissed()
        }
    }

    Timer {
        id: activateTimer
        interval: 50
        onTriggered: {
            grab.active = true
            settleTimer.restart()
            root.focused()
        }
    }

    Timer {
        id: settleTimer
        interval: 200
    }

    on_WantChanged: {
        if (_want) {
            _retries = 0
            activateTimer.restart()
        } else {
            activateTimer.stop()
            settleTimer.stop()
            grab.active = false
        }
    }

    Component.onCompleted: if (_want) activateTimer.restart()
}
