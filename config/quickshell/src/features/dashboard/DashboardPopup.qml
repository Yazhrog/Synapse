import QtQuick
import qs.src.core.specs
import qs.src.state
import qs.src.theme
// The dashboard: drops from the center notch, as wide as its page.
PopupSpec {
    key:    "dashboard"
    region: "top"
    pageProp:        "dashboardPage"
    defaultPagePref: "defaultDashboardPage"
    size:   s => [s.px(Popups.dashboardPageWidth), s.px(Theme.dashboardHeight)]
    place:  (s, w, h) => Qt.rect(s.px(8), s.px(Theme.notchRadius + 8),
                                 s.px(Popups.dashboardPageWidth - 16),
                                 s.px(Theme.dashboardHeight - Theme.notchRadius - 16))
    focus:  item => item.focusPage()
    afterClose: item => item.reset()
    component: Component { DashboardContent {} }
}
