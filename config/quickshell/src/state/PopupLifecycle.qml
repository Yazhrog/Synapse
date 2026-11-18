import QtQuick

// PopupLifecycle — reacts to one popup's lifecycle (SurfaceState).
//
//   PopupLifecycle {
//       popup: "network"
//       onOpening: WifiService.scan(false)        // asked to open
//       onClosed:  board.reset()                 // after the close animation
//   }
//
// `screen` limits it to one screen ("" = any). `phase` is the current phase
// there ("closed", "opening", "open", "closing").
QtObject {
    id: root

    property string popup:  ""
    property string screen: ""

    readonly property string phase: {
        const _dep = SurfaceState._phases
        return SurfaceState.phaseOf(popup, screen)
    }

    signal opening()
    signal opened()
    signal closing()
    signal closed()

    function _mine(key, screen) { return key === root.popup && (root.screen === "" || root.screen === screen) }

    property Connections _c: Connections {
        target: SurfaceState
        function onOpening(key, screen) { if (root._mine(key, screen)) root.opening() }
        function onOpened(key, screen)  { if (root._mine(key, screen)) root.opened() }
        function onClosing(key, screen) { if (root._mine(key, screen)) root.closing() }
        function onClosed(key, screen)  { if (root._mine(key, screen)) root.closed() }
    }
}
