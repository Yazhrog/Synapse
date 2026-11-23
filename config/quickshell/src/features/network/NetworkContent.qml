import QtQuick
import qs.src.components.base
import qs.src.core
import qs.src.services.network
import qs.src.state
// NetworkContent — the network popup's UI: the tab pages and the tab bar,
// both from NetworkTabs. Hosted by the right region of DynamicSurface.
Item {
    id: root

    property string page: "wifi"

    NetworkTabs { id: registry }

    // VpnService follows NetworkManager while the popup is open.
    Lease { service: VpnService; active: Popups.networkOpen }

    // ── Tab page area ─────────────────────────────────────────────────
    Item {
        id: tabContent
        anchors {
            top:    parent.top
            left:   parent.left
            right:  parent.right
            bottom: tabBar.top
            bottomMargin: 8
        }

        PageStack {
            anchors.fill: parent
            pages:   registry.pages
            current: root.page
            lazy:    true
        }
    }

    // ── Tab bar — kept clear of the popup's bottom edge ───────────────
    TabSwitcher {
        id: tabBar
        anchors {
            left:         parent.left
            right:        parent.right
            bottom:       parent.bottom
            bottomMargin: 8
        }
        orientation: "horizontal"
        divider:      false
        width:        parent.width
        currentPage:  root.page
        model:        Array.from(registry.pages, p => ({ key: p.key, icon: p.icon, label: p.label }))
        onPageChanged: function(key) { Popups.networkPage = key }
    }
}
