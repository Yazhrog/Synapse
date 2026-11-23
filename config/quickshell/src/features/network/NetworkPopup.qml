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
    size:   s => [s.px(Theme.frame.networkPopupBodyWidth) + s.borderWidth,
                  s.px(Theme.frame.networkPopupHeight - Theme.radius.notch)]
    place:  (s, w, h) => Qt.rect(s.px(Theme.radius.notch), 0,
                                 s.px(Theme.frame.networkPopupBodyWidth - Theme.radius.notch - 7),
                                 s.px(Theme.frame.networkPopupHeight - Theme.radius.notch - Theme.radius.card) - s.notchHeight)
    component: Component { NetworkContent { page: Popups.networkPage || "wifi" } }
}
