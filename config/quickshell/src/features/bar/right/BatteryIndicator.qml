import QtQuick
import qs.src.services.data
Item {
    // Always show the percentage beside the icon; otherwise only on hover.
    property bool showPercentage: Prefs.data.alwaysShowBatteryPercentage

    implicitWidth:  status.implicitWidth
    implicitHeight: status.implicitHeight

    BatteryStatus {
        id:               status
        anchors.centerIn: parent
        showPercentage:   parent.showPercentage
    }

    // No click action: there is no battery popup yet (#17).
}
