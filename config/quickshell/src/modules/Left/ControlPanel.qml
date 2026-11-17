import QtQuick
import Quickshell
import qs.src.components
import qs.src.state
IconBtn {
		text: "" 
		textColor: "#1793d1"
		onClicked: {
        Popups.toggle("powerMenu", QsWindow.window?.screen?.name ?? "")
    }
}
