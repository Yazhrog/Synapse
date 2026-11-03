import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Notifications
import "../shapes/"
import "../components/"
import "../services/"
import "../"

PopupWindow {
	id: root

	required property var anchorWindow

	readonly property int toastWidth: Theme.notificationToastWidth+(fw/2)
	readonly property int fw: Theme.notchRadius
	readonly property int fh: Theme.notchRadius

	implicitWidth:  toastWidth + fw
	implicitHeight: 220

	anchor.window: root.anchorWindow
	anchor.rect: Qt.rect(
		root.anchorWindow.width - toastWidth/2-fw+1,
		-Theme.notchHeight-20,
		toastWidth,
		Theme.notchHeight
	)
	anchor.gravity:    Edges.Bottom
	anchor.adjustment: PopupAdjustment.None

	color:   "transparent"
	visible: windowVisible

	// The queue and timers live in ToastState; this window only renders the
	// toast on the screen it was shown on.
	readonly property bool _here: ToastState.isOn(root.anchorWindow.screen ? root.anchorWindow.screen.name : "")
	readonly property bool showing: _here && ToastState.showing
	property bool windowVisible: false

	on_HereChanged: if (_here) { hideTimer.stop(); windowVisible = true } else hideTimer.restart()

	// Keep the window mapped until the slide-out finishes.
	Timer {
		id:       hideTimer
		interval: Theme.animDuration + 20
		onTriggered: root.windowVisible = false
	}

	// ── Card ───────────────────────────────────────────────────
	Item {
		id:            card
		anchors.right: parent.right
		anchors.top:   parent.top
		clip:           true

		width: root.showing
		? root.toastWidth + root.fw
		: root.fw

		height: root.showing
		? (toastCard.y + toastCard.implicitHeight + 24 + root.fh)
		: root.fh

		Behavior on width  { NumberAnimation { duration: Theme.animDuration; easing.type: Easing.InOutCubic } }
		Behavior on height { NumberAnimation { duration: Theme.animDuration; easing.type: Easing.InOutCubic } }

		PopupShape {
			anchors.fill: parent
			attachedEdge: "right"
			color:        Theme.background
			radius:       Theme.cornerRadius
			flareWidth:   root.fw
			flareHeight:  root.fh
		}

		ToastCard {
			id: toastCard
			anchors {
				left:        parent.left;  leftMargin:  14
				right:       parent.right; rightMargin: root.fw
			}
			y:        root.fh + 6
			barWidth: root.toastWidth - 10
			opacity:  root.showing ? 1 : 0
			Behavior on opacity { NumberAnimation { duration: 150 } }
		}
	}
}
