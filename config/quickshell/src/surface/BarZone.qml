import QtQuick
import qs.src.services.data
// BarZone — one zone of the bar: its widgets (BarWidgetSpec, from
// features/bar/BarWidgets.qml via the manifest) in a Row, in
// PrefsService.barLayout's order for the zone, else by defaultOrder.
// Widgets get `localScale` if they declare it.
Row {
    id: zoneRow

    required property string zone
    property var  widgets:    []
    property real localScale: 1.0

    readonly property var ordered: {
        const mine = Array.from(widgets).filter(w => w.zone === zone)
        const layout = PrefsService.barLayout ? PrefsService.barLayout[zone] : undefined
        if (Array.isArray(layout))
            return layout.map(k => mine.find(w => w.key === k)).filter(w => w !== undefined)
        return mine.sort((a, b) => a.defaultOrder - b.defaultOrder)
    }

    Repeater {
        model: zoneRow.ordered
        delegate: Loader {
            required property var modelData
            // A Row top-aligns its children: center the widgets that ask for it.
            anchors.verticalCenter: modelData.centered ? parent.verticalCenter : undefined
            sourceComponent: modelData.component
            onLoaded: if ("localScale" in item) item.localScale = Qt.binding(() => zoneRow.localScale)
        }
    }
}
