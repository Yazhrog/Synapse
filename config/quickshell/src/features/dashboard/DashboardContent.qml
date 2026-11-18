import QtQuick
import qs.src.components.base
import qs.src.state
// DashboardContent — the dashboard UI: the tab bar and the page area, both
// from DashboardPages. Hosted by the top region of DynamicSurface; the popup
// width per page comes from DashboardPages too (DashboardPopup).
Item {
    id: root

    property string page: Popups.dashboardPage

    DashboardPages { id: registry }

    // Runs after the close animation (the spec's afterClose): back to the
    // default tab, Config's first tab scrolled to the top and the clock view.
    function reset() {
        tabBar.reset()
        stack.resetAll()
    }
    // Gives focus back to whichever page item last had it (e.g. the launcher search).
    function focusPage() { pageArea.forceActiveFocus() }

    // A page can dim the tab bar (Tasks, behind its delete dialog).
    readonly property real _tabBarOpacity: {
        let o = 1
        for (const k in stack.items) {
            const it = stack.items[k]
            if (it && it.tabBarOpacity !== undefined) o = Math.min(o, it.tabBarOpacity)
        }
        return o
    }

    Column {
        anchors.fill: parent
        spacing: 0

        // ── Tab bar ───────────────────────────────────────────────────
        TabSwitcher {
            id: tabBar
            orientation: "horizontal"
            width:       parent.width
            currentPage: root.page
            model:       Array.from(registry.pages, p => ({ key: p.key, icon: p.icon, label: p.label }))
            onPageChanged: function(key) { Popups.dashboardPage = key }
            opacity: root._tabBarOpacity
            Behavior on opacity { NumberAnimation { duration: 150 } }
        }

        // ── Page area ─────────────────────────────────────────────────
        // FocusScope so forceActiveFocus() from the focus grab restores
        // whichever page item last held focus (e.g. the launcher search)
        // instead of taking it for itself.
        FocusScope {
            id: pageArea
            focus: true

            width:  parent.width
            height: parent.height - tabBar.height

            PageStack {
                id: stack
                anchors.fill: parent
                pages:   registry.pages
                current: root.page
                host:    root
            }

            Keys.onEscapePressed: Popups.close("dashboard")
        }
    }
}
