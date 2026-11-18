import QtQuick
import qs.src.core.specs
import qs.src.state
import qs.src.theme
// The wallpaper picker: a panel on the bottom border.
PopupSpec {
    key:    "wallpaper"
    region: "bottomCenter"
    size:   s => [s.px(Metrics.wallpaperPanelWidth), s.px(Metrics.wallpaperPanelHeight)]
    place:  (s, w, h) => Qt.rect((w - s.px(Metrics.wallpaperPanelWidth) - 2 * s.notchRadius) / 2, 0,
                                 s.px(Metrics.wallpaperPanelWidth) + 2 * s.notchRadius,
                                 s.px(Metrics.wallpaperPanelHeight))
    focus:  item => item.focusSearch()
    component: Component {
        WallpaperContent {
            property var    surface:    null
            property string screenName: ""
            fw:        surface ? surface.notchRadius : Theme.notchRadius
            fh:        surface ? surface.notchRadius : Theme.notchRadius
            edgeInset: surface && surface.framed ? surface.borderWidth : 0
            open:      SurfaceState.isOpenOn("wallpaper", screenName)
        }
    }
}
