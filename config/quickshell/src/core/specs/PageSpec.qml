import QtQuick

// PageSpec — one page of a popup with tabs (dashboard pages, audio pages,
// network tabs). Listed in the feature's registry (DashboardPages,
// AudioPages, NetworkTabs); the tab bar, the page stack, the popup width,
// Config → General's default-page options and the toggle action read it.
//
//   PageSpec { key: "calendar"; label: "Calendar"; icon: "󰃭"
//              component: Component { CalendarPage {} }
//              action: "dashboard-calendar"; actionLabel: "Dashboard: Calendar" }
//
// The page item gets `host` (the popup content) if it declares it; its
// reset(), if any, runs when the popup is closed.
QtObject {
    required property string key
    property string label: key
    property string icon:  ""
    property int    width: 0              // popup width on this page (0 = the popup's default)
    property Component component: null
    property string action:      ""        // toggle action key, "" = none
    property string actionLabel: label
}
