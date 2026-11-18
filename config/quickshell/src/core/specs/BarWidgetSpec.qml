import QtQuick

// BarWidgetSpec — one widget of the bar (features/bar/BarWidgets.qml).
//
// `zone` is "left", "center" or "right"; the default layout orders each zone
// by `defaultOrder`, PrefsService.barLayout ({ left: [keys], … }) overrides
// it (the picker comes with #23). `centered` centres the widget vertically
// in its zone's row (a Row top-aligns otherwise).
QtObject {
    required property string key
    property string label: key
    required property string zone
    property int    defaultOrder: 0
    property bool   centered: false
    property Component component: null
}
