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
    property var _focusMode:  FocusModeService

    // One Dynamic Surface per screen (#37): frame, bar and every popup.
    ShellHost {}
}
