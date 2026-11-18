import QtQuick
import qs.src.core.specs
import qs.src.state
import qs.src.theme
// The network popup: grows the right notch.
PopupSpec {
    readonly property NetworkTabs _registry: NetworkTabs {}
    key:    "network"
    region: "right"
    actionGroup: "Network Tabs"
    pages:    _registry.pages
    pageProp: "networkPage"
    size:   s => [s.px(Metrics.networkPopupBodyWidth) + s.borderWidth,
                  s.px(Metrics.networkPopupHeight - Theme.notchRadius)]
    place:  (s, w, h) => Qt.rect(s.px(Theme.notchRadius), 0,
                                 s.px(Metrics.networkPopupBodyWidth - Theme.notchRadius - 7),
                                 s.px(Metrics.networkPopupHeight - Theme.notchRadius - Theme.cornerRadius) - s.notchHeight)
    component: Component { NetworkContent { page: Popups.networkPage || "wifi" } }
}
