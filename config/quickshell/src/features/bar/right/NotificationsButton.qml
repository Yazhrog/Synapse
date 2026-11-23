import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import qs.src.components.base
import qs.src.services.notifications
import qs.src.state
IconBtn {
    text: ShellModes.dnd
          ? "󰂛"
          : NotificationService.count > 0 ? "󰂚" : "󰂜"

    onClicked: {
        Popups.toggle("notifications", QsWindow.window?.screen?.name ?? "")
    }
}