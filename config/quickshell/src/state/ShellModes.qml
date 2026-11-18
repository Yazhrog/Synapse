pragma Singleton
import Quickshell
import QtQuick
import qs.src.services.desktop
import qs.src.services.media
import qs.src.services.notifications
// ShellModes — read-only mirrors of the shell's mode flags, for the surface
// and the bar. Each flag is owned by its service; change it there.
//
// focusMode     — FocusModeService.active; the surface collapses the bar and its strut reserves nothing
// dnd           — NotificationService.dnd (drops incoming notifications)
// screenRecord  — ScreenRecService.setupOpen (the recording setup is shown)
// airplane      — QuickToggleService.airplaneOn (rfkill)
//
// Wi-Fi, Bluetooth, VPN, the hotspot, Night Light and Caffeine are read
// straight from their services. The Hyprland config provider is Hypr.provider.
Singleton {
    readonly property bool focusMode:    FocusModeService.active
    readonly property bool dnd:          NotificationService.dnd
    readonly property bool screenRecord: ScreenRecService.setupOpen
    readonly property bool airplane:     QuickToggleService.airplaneOn
}
