import QtQuick
import Quickshell
import "../../components"
import "../../windows"
import "../../"

Row {
	// Set by the Dynamic Surface host (#39); contents adopt it progressively.
	property real localScale: 1.0

	spacing: 5
	// Note: Do NOT add anchors.centerIn: parent here. DynamicSurface centres it in the left notch.

	// 1. Arch Icon (Power Menu Trigger)
	ControlPanel{}

	// 2. Workspaces
	Workspaces {} 
	
	//3. LayoutDisplay
	LayoutDisplayer {}

}
