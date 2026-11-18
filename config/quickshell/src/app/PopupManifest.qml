import QtQuick
import qs.src.core.specs
import qs.src.features.audio
import qs.src.features.clipboard
import qs.src.features.dashboard
import qs.src.features.network
import qs.src.features.notifications
import qs.src.features.osd
import qs.src.features.power
import qs.src.features.screenrec
import qs.src.features.wallpaper
// PopupManifest — every popup of the shell, and the passive parts the
// Dynamic Surface hosts. App hands it to SurfaceState (keys, regions,
// pages) and to the surface (sizes, placement, focus, contents); the surface
// never imports a feature.
//
// Adding a popup: a PopupSpec file in its feature folder, one line here.
// The order is the stacking order of the popups on the surface.
QtObject {
    readonly property list<PopupSpec> popups: [
        PowerPopup {},
        AudioPopup {},
        NotificationsPopup {},
        NetworkPopup {},
        DashboardPopup {},
        WallpaperPopup {},
        ClipboardPopup {}
    ]

    // Passive content: the Quick Controls OSD (right-center region) and the
    // screen-recording options (under the center notch).
    readonly property Component osd:              Component { QuickControlContent {} }
    readonly property Component recordingOptions: Component { ScreenRecOptions {} }
}
