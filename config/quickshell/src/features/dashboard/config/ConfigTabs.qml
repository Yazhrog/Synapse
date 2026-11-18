import QtQuick
import qs.src.core.specs
import qs.src.features.dashboard.config.pages
// ConfigTabs — the tabs of Config (ShellConfig), in order. A tab's reset(),
// if any, runs when the dashboard closes.
QtObject {
    readonly property list<TabSpec> tabs: [
        TabSpec { key: "general";    icon: "󰒓"; label: "General";           component: Component { GeneralPage {} } },
        TabSpec { key: "appearance"; icon: "󰏘"; label: "Appearance";        component: Component { AppearancePage {} } },
        TabSpec {
            key: "layout"; icon: "󰕰"; label: "Layout & Behavior"
            component: Component {
                Item { Text { anchors.centerIn: parent; text: "Layout & Behavior Coming Soon!"; font.pixelSize: 13; color: Qt.rgba(1,1,1,0.12) } }
            }
        },
        TabSpec { key: "data";       icon: "󰋊"; label: "Data & Storage";    component: Component { DataPage {} } },
        TabSpec { key: "keybinds";   icon: "󰌌"; label: "Keybinds";          component: Component { KeybindsPage {} } },
        TabSpec { key: "misc";       icon: "󰇘"; label: "Misc";              component: Component { MiscPage {} } }
    ]
}
