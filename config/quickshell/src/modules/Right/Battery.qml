import QtQuick
import "../../services"
import "../../"

Item {
    // Always show the percentage beside the icon; otherwise only on hover.
    property bool showPercentage: PrefsService.alwaysShowBatteryPercentage

    implicitWidth:  status.implicitWidth
    implicitHeight: status.implicitHeight

    BatteryStatus {
        id:               status
        anchors.centerIn: parent
        showPercentage:   parent.showPercentage
    }

    // No click action: there is no battery popup yet (#17).
}
