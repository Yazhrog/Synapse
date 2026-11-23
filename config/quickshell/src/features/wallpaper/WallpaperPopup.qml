import QtQuick
import qs.src.core.specs
import qs.src.state
import qs.src.theme
// The wallpaper picker: a panel on the bottom border.
PopupSpec {
    key:    "wallpaper"
    region: "bottomCenter"
    action: "wallpaper-toggle"; actionLabel: "Wallpaper"
    size:   s => [s.px(Theme.frame.wallpaperPanelWidth), s.px(Theme.frame.wallpaperPanelHeight)]
    place:  (s, w, h) => Qt.rect((w - s.px(Theme.frame.wallpaperPanelWidth) - 2 * s.notchRadius) / 2, 0,
                                 s.px(Theme.frame.wallpaperPanelWidth) + 2 * s.notchRadius,
                                 s.px(Theme.frame.wallpaperPanelHeight))
    focus:  item => item.focusSearch()
    component: Component {
        WallpaperContent {
            property var    surface:    null
            property string screenName: ""
            fw:        surface ? surface.notchRadius : Theme.radius.notch
            fh:        surface ? surface.notchRadius : Theme.radius.notch
            edgeInset: surface && surface.framed ? surface.borderWidth : 0
            open:      SurfaceState.isOpenOn("wallpaper", screenName)
        }
    }
}
