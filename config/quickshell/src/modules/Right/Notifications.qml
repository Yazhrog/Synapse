import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import qs.src.components
import qs.src.services.notifications
import qs.src.state
IconBtn {
    text: ShellState.dnd
          ? "󰂛"
          : NotificationService.count > 0 ? "󰂚" : "󰂜"

    onClicked: {
        Popups.toggle("notifications", QsWindow.window?.screen?.name ?? "")
    }
}