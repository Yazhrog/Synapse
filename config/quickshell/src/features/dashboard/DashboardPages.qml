import QtQuick
import qs.src.core.specs
import qs.src.features.dashboard.apps
import qs.src.features.dashboard.config
import qs.src.features.dashboard.home
import qs.src.features.dashboard.system
import qs.src.features.dashboard.tasks
// DashboardPages — the dashboard's pages, in tab order (ARCHITECTURE.md §10.1).
// The tab bar, the page stack, the dashboard's width, the toggle actions
// (app/ActionManifest.qml) and Config → General's "Default dashboard tab"
// read this list. A page gets `host` (the DashboardContent) if it declares it.
QtObject {
    readonly property list<PageSpec> pages: [
        PageSpec {
            key: "home"; label: "Home"; icon: "󰋜"; width: 900
            action: "dashboard-home"; actionLabel: "Dashboard: Home"
            component: Component { HomePage {} }
        },
        PageSpec {
            key: "stats"; label: "System"; icon: "󰻠"; width: 900
            action: "dashboard-stats"; actionLabel: "Dashboard: System"
            component: Component { SystemPage {} }
        },
        PageSpec {
            key: "kanban"; label: "Tasks"; icon: "󰄬"; width: 900
            action: "dashboard-kanban"; actionLabel: "Dashboard: Tasks"
            component: Component {
                TaskBoard {
                    property var host: null
                    overlayParent: host
                    // The tab bar fades with the board behind the delete dialog.
                    readonly property real tabBarOpacity: delConfirmId >= 0 ? dimOpacity : 1
                }
            }
        },
        PageSpec {
            key: "launcher"; label: "Apps"; icon: "󱓞"; width: 560
            action: "dashboard-launcher"; actionLabel: "Dashboard: Apps"
            component: Component { AppLauncher {} }
        },
        PageSpec {
            key: "config"; label: "Config"; icon: "󰒓"; width: 900
            action: "dashboard-config"; actionLabel: "Dashboard: Config"
            component: Component { ShellConfig {} }
        }
    ]

    function widthOf(key: string): int {
        for (let i = 0; i < pages.length; i++) if (pages[i].key === key && pages[i].width > 0) return pages[i].width
        return 900
    }
}
