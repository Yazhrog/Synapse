import QtQuick
import qs.src.core.specs
import qs.src.state
import qs.src.theme
// The dashboard: drops from the center notch, as wide as its page.
PopupSpec {
    readonly property DashboardPages _registry: DashboardPages {}
    key:    "dashboard"
    region: "top"
    actionGroup: "Dashboard"
    pages:           _registry.pages
    pageProp:        "dashboardPage"
    defaultPagePref: "defaultDashboardPage"
    size:   s => [s.px(_registry.widthOf(Popups.dashboardPage)), s.px(Theme.dashboardHeight)]
    place:  (s, w, h) => Qt.rect(s.px(8), s.px(Theme.notchRadius + 8),
                                 s.px(_registry.widthOf(Popups.dashboardPage) - 16),
                                 s.px(Theme.dashboardHeight - Theme.notchRadius - 16))
    focus:  item => item.focusPage()
    afterClose: item => item.reset()
    component: Component { DashboardContent {} }
}
