import QtQuick
import qs.src.core.specs
import qs.src.state
import qs.src.theme
// The network popup: grows the right notch.
PopupSpec {
    key:    "network"
    region: "right"
    pageProp: "networkPage"
    size:   s => [s.px(Metrics.networkPopupBodyWidth) + s.borderWidth,
                  s.px(Metrics.networkPopupHeight - Theme.notchRadius)]
    place:  (s, w, h) => Qt.rect(s.px(Theme.notchRadius), 0,
                                 s.px(Metrics.networkPopupBodyWidth - Theme.notchRadius - 7),
                                 s.px(Metrics.networkPopupHeight - Theme.notchRadius - Theme.cornerRadius) - s.notchHeight)
    component: Component { NetworkContent { page: Popups.networkPage || "wifi" } }
}
