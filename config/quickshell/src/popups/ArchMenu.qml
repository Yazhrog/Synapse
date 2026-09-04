import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "../shapes"
import "../services"
import "../components"
import "../"

PopupWindow {
	id: root

	required property var anchorWindow

	readonly property int fw: Theme.cornerRadius
	readonly property int fh: Theme.cornerRadius

	readonly property var pageHeights: ({
		"power":       270,
		"performance": 190,
		"stats":       250
	})
	readonly property var pageWidths: ({
		"power":       220,
		"performance": 260,
		"stats":       390
	})

	readonly property int contentWidth:  pageWidths[page]  ?? 220
	readonly property int contentHeight: pageHeights[page] ?? 220

	property string page: "power"

	color:   "transparent"
	visible: slide.windowVisible
	mask: Region { item: maskProxy }

	implicitWidth:  (pageWidths["stats"]  ?? 220) + fw
	implicitHeight: (pageHeights["stats"] ?? 220) + fh * 2

	anchor.window:  anchorWindow
	anchor.gravity: Edges.Right
	anchor.rect: Qt.rect(
		0,
		anchorWindow.height / 2,
		anchorWindow.width,
		implicitHeight
	)
	
	Item {
		id:      maskProxy
		x:       0
		y:       (root.implicitHeight - sizer.height) / 2-root.fh
		width:   sizer.width
		height:  sizer.height
	}

	// Hyprland-native keyboard grab — xdg-popup surfaces don't pick up
	// keyboard focus on their own, and wlr-layer-shell's Exclusive focus
	// mode isn't applicable to a PopupWindow. This grabs real keyboard
	// input for as long as the menu is visible so PowerMenu's arrow-key
	// navigation actually receives events.
	//
	// Activation is deliberately delayed a tick after the popup becomes
	// visible: requesting the grab in the same frame the surface is mapped
	// gets rejected (surface not committed yet), which fires `cleared`
	// immediately. `cleared` is intentionally NOT wired to close the popup —
	// PopupDismiss already owns click-outside/Escape dismissal, and closing
	// here as well caused exactly that reject-then-immediately-close loop.
	HyprlandFocusGrab {
		id:      focusGrab
		windows: [root]
	}

	Timer {
		id: grabTimer
		interval: 50
		onTriggered: {
			focusGrab.active = true
			powerMenu.reset()
		}
	}

	Connections {
		target: Popups
		function onArchMenuOpenChanged() {
			if (Popups.archMenuOpen) {
				grabTimer.restart()
			} else {
				focusGrab.active = false
			}
		}
	}

	PopupSlide {
		id: slide
		anchors.fill: parent
		edge:             "left"
		hoverEnabled:     false
		triggerHovered:   Popups.archMenuTriggerHovered
		open:             Popups.archMenuOpen
		onCloseRequested: Popups.archMenuOpen = false

		Item {
			id: sizer
			anchors.left:           parent.left
			anchors.verticalCenter: parent.verticalCenter
			clip: true

			width:  root.contentWidth  + root.fw
			height: root.contentHeight + root.fh * 2

			Behavior on width  { NumberAnimation { duration: Theme.animDuration; easing.type: Easing.InOutCubic } }
			Behavior on height { NumberAnimation { duration: Theme.animDuration; easing.type: Easing.InOutCubic } }

			PopupShape {
				id: bg
				anchors.fill: parent
				attachedEdge: "left"
				color:        Theme.background
				radius:       Theme.cornerRadius
				flareWidth:   root.fw
				flareHeight:  root.fh
			}

			Item {
				anchors {
					fill:         parent
					leftMargin:   root.fw - 4
					rightMargin:  8
					topMargin:    root.fh + 6
					bottomMargin: root.fh + 6
				}
					//── Page content ──────────────────────────────────────────
					Item {
						width:  parent.width
						height: parent.height
						clip:   true

						PopupPage {
							anchors.fill: parent
							visible: root.page === "power"

							PowerMenu {
								id:    powerMenu
								width: parent.width
							}
						}
				}
			}
		}
	}
}