pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.UPower

// BatteryService — the battery state from UPower, shared by the bar
// indicator and the low-battery warnings.
//   percent (0–100), charging (charging, pending or full), full, ready
Singleton {
    readonly property var  device:   UPower.displayDevice
    readonly property bool ready:    device.ready
    readonly property real percent:  ready ? Math.round(device.percentage * 100) : 0
    readonly property bool charging: ready && (device.state === UPowerDeviceState.Charging
                                               || device.state === UPowerDeviceState.PendingCharge
                                               || device.state === UPowerDeviceState.FullyCharged)
    readonly property bool full:     ready && device.state === UPowerDeviceState.FullyCharged
}
