import QtQuick
import "../../"

// CavaBars — a row of rounded bars that grow symmetrically from the middle,
// one per value in `bars` (0–100). `tint` at minAlpha…1 by amplitude, or a
// faint white when `muted`.

Item {
    id: root

    property var   bars:       []
    property real  barWidth:   5
    property real  barSpacing: 1
    property color tint:       Theme.active
    property real  minAlpha:   0.28
    property bool  muted:      false

    readonly property real _maxH: height / 2

    Row {
        anchors.fill: parent
        spacing:      root.barSpacing

        Repeater {
            model: root.bars
            delegate: Item {
                required property int modelData
                width:  root.barWidth
                height: root.height
                readonly property real _amp: modelData / 100.0
                Rectangle {
                    anchors.centerIn: parent
                    width:  root.barWidth
                    height: Math.max(2, _amp * root._maxH * 2)
                    radius: width / 2
                    color:  root.muted
                            ? Qt.rgba(1, 1, 1, 0.10)
                            : Qt.rgba(root.tint.r, root.tint.g, root.tint.b, root.minAlpha + _amp * (1 - root.minAlpha))
                    Behavior on height { NumberAnimation { duration: 50; easing.type: Easing.OutCubic } }
                }
            }
        }
    }
}
