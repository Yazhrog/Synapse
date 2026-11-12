import QtQuick
import "../components"
import "../modules/Center/"
import "../services/"
// Imported explicitly so quickshell scans these folders: they are only listed
// in services/qmldir, and their files' own imports (clock/, components/sliders,
// KeybindRow, …) are not found otherwise. tests/smoke-imports.qml checks this.
import "../services/home"
import "../services/config_tab"
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
            // Fades with the board behind the task delete dialog
            opacity: kanbanBoard.delConfirmId >= 0 ? kanbanBoard.dimOpacity : 1
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
                KanbanBoard { id: kanbanBoard; anchors.fill: parent; overlayParent: root }
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
