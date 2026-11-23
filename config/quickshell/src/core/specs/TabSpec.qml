import QtQuick

// TabSpec — one tab of a tabbed view that isn't a popup page (Config's
// tabs, features/dashboard/config/ConfigTabs.qml). The tab item's reset(),
// if any, runs when the dashboard closes.
QtObject {
    required property string key
    property string label: key
    property string icon:  ""
    property Component component: null
}
