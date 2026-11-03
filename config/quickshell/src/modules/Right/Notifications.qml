import QtQuick
import Quickshell.Services.SystemTray
import "../../components"
import "../../windows"
import "../../"
import "../../services/"

IconBtn {
    text: ShellState.dnd
          ? "󰂛"
          : NotificationService.count > 0 ? "󰂚" : "󰂜"

    onClicked: {
        Popups.toggle("notifications")
    }
}