import QtQuick
import qs.src.core.specs
import qs.src.features.bar.center
import qs.src.features.bar.left
import qs.src.features.bar.right
// BarWidgets — every widget of the bar, by zone (ARCHITECTURE.md §10.3).
// The surface lays each zone out in `defaultOrder`, or in
// Prefs.data.barLayout's order when it lists the zone.
QtObject {
    readonly property list<BarWidgetSpec> widgets: [
        BarWidgetSpec { key: "power";      zone: "left"; defaultOrder: 10; label: "Power menu"; component: Component { PowerButton {} } },
        BarWidgetSpec { key: "workspaces"; zone: "left"; defaultOrder: 20; label: "Workspaces"; component: Component { Workspaces {} } },
        BarWidgetSpec { key: "layout";     zone: "left"; defaultOrder: 30; label: "Layout";     component: Component { LayoutIndicator {} } },

        BarWidgetSpec { key: "notch"; zone: "center"; defaultOrder: 10; label: "Notch carousel"; component: Component { CenterContent {} } },

        BarWidgetSpec { key: "network";       zone: "right"; defaultOrder: 10; centered: true; label: "Network";       component: Component { NetworkIndicator {} } },
        BarWidgetSpec { key: "audio";         zone: "right"; defaultOrder: 20; centered: true; label: "Volume";        component: Component { AudioIndicator {} } },
        BarWidgetSpec { key: "battery";       zone: "right"; defaultOrder: 30; centered: true; label: "Battery";       component: Component { BatteryIndicator {} } },
        BarWidgetSpec { key: "clock";         zone: "right"; defaultOrder: 40; centered: true; label: "Clock";         component: Component { Clock {} } },
        BarWidgetSpec { key: "tray";          zone: "right"; defaultOrder: 50; centered: true; label: "System tray";   component: Component { SysTray {} } },
        BarWidgetSpec { key: "notifications"; zone: "right"; defaultOrder: 60; centered: true; label: "Notifications"; component: Component { NotificationsButton {} } }
    ]
}
