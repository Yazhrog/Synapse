import QtQuick
import "../components"
import "../modules/Center/"
import "../services/"
import "../"

// DashboardContent — the dashboard UI: tab bar (Home / System / Tasks / Apps /
// Config) and the page area. Hosted by the top region of DynamicSurface. The popup width per page comes from
// Popups.dashboardPageWidth.
Item {
    id: root

    property string page: Popups.dashboardPage

    // Back to the default tab look after the popup closed.
    function reset() { tabBar.reset() }
    // Gives focus back to whichever page item last had it (e.g. the launcher search).
    function focusPage() { pageArea.forceActiveFocus() }

    Column {
        anchors.fill: parent
        spacing: 0

        // ── Tab bar ───────────────────────────────────────────────────
        TabSwitcher {
            id: tabBar
            orientation: "horizontal"
            width:       parent.width
            currentPage: root.page
            model: [
                { key: "home",     icon: "󰋜", label: "Home"   },
                { key: "stats",    icon: "󰻠", label: "System" },
                { key: "kanban",   icon: "󰄬", label: "Tasks"  },
                { key: "launcher", icon: "󱓞", label: "Apps"   },
                { key: "config",   icon: "󰒓", label: "Config" },
            ]
            onPageChanged: function(key) { Popups.dashboardPage = key }
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

            Item {
                anchors.fill: parent
                visible:      root.page === "home"
                DashHome { anchors.fill: parent }
            }

            Item {
                anchors.fill: parent
                visible:      root.page === "stats"
                DashStats { anchors.fill: parent }
            }

            Item {
                anchors.fill: parent
                visible:      root.page === "kanban"
                KanbanBoard { anchors.fill: parent; overlayParent: root }
            }

            Item {
                anchors.fill: parent
                visible:      root.page === "launcher"
                AppLauncher { anchors.fill: parent }
            }

            Item {
                anchors.fill: parent
                visible:      root.page === "config"
                Item {
                    anchors.fill: parent
                    visible:      root.page === "config"
                    ShellConfig { anchors.fill: parent }
                }
            }

            Keys.onEscapePressed: Popups.close("dashboard")
        }
    }
}
