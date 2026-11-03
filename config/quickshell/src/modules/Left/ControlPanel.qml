import QtQuick
import Quickshell
import "../../components"
import "../../"

IconBtn {
		text: "" 
		textColor: "#1793d1"
		onClicked: {
        Popups.toggle("powerMenu", QsWindow.window?.screen?.name ?? "")
    }
}
