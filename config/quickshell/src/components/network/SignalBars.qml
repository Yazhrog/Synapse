import QtQuick
import "../../"

// SignalBars — four bars lit by Wi-Fi signal strength (0–100).

Item {
    id: barsRoot
    required property int signal
    width: 18; height: 14
    Row {
        anchors.bottom: parent.bottom; anchors.horizontalCenter: parent.horizontalCenter; spacing: 2
        Repeater {
            model: 4
            delegate: Rectangle {
                required property int index
                width: 3; height: 4 + index * 3; radius: 1; anchors.bottom: parent?.bottom
                readonly property bool lit: {
                    switch (index) {
                        case 0: return barsRoot.signal > 0
                        case 1: return barsRoot.signal > 25
                        case 2: return barsRoot.signal > 50
                        case 3: return barsRoot.signal > 75
                    }; return false
                }
                color: lit ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.85) : Qt.rgba(1,1,1,0.15)
                Behavior on color { ColorAnimation { duration: 200 } }
            }
        }
    }
}
