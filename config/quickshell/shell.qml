//@ pragma UseQApplication

import Quickshell
import QtQuick
import "./src/windows"
import "./src/"

ShellRoot {
    // Force-instantiate lazy singletons that need startup behavior
    property var _keybinds:   KeybindService
    property var _updater:    UpdateService
    property var _ipc:        IpcManager
    property var _battery:    BatteryWarningService

    // SYNAPSE_SURFACE=1 runs the Dynamic Surface host (#37) instead of the
    // legacy window stack. Read once at startup.
    readonly property bool useSurface: Quickshell.env("SYNAPSE_SURFACE") === "1"

    LazyLoader {
        active: !useSurface
        component: LegacyHost {}
    }

    LazyLoader {
        active: useSurface
        component: ShellHost {}
    }
}
