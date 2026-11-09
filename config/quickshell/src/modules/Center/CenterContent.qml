import QtQuick
import Quickshell
import Quickshell.Services.Mpris
import "../../"

// CenterContent — the centre notch's scrollable carousel ("dynamic island").
//
// Items, in order (each only while it applies):
//   "title"         — the focused app (always there)
//   "music"         — an MPRIS player exists
//   "timer"         — ClockState.timerStarted
//   "stopwatch"     — ClockState.swStarted
//   "record_setup"  — screen-recording setup is open
//   "record_active" — recording
//
// New items scroll into view when the carousel is on the title; screen
// recording always does. The timer forces itself into view at 30 s and 10 s
// left, and blinks red under 30 s. Each item is its own component
// (Notch*Item.qml, next to this file).

Item {
	// Set by the Dynamic Surface host (#39); contents adopt it progressively.
	property real localScale: 1.0

	id: root

	width:  Theme.cNotchMinWidth
	height: 30

	// DynamicSurface sizes the centre notch from it.
	readonly property int fw: Theme.notchRadius
	readonly property int requiredWidth: Theme.cNotchMinWidth

	// ── MPRIS ─────────────────────────────────────────────────────────────────
	readonly property var    player: Mpris.players.values.length > 0 ? Mpris.players.values[0] : null
	readonly property string artUrl: player?.trackArtUrl ?? ""

	// ── Dynamic item list ─────────────────────────────────────────────────────
	property var  _items:         ["title"]
	property int  _carouselIndex: 0
	readonly property real _itemStride: 45  // 30px height + 15px spacing

	function _rebuildItems(autoScrollType) {
		var currentType = (_items.length > _carouselIndex)
		? _items[_carouselIndex] : "title"

		var list = ["title"]
		if (root.player                    !== null) list.push("music")
		if (ClockState.timerStarted)                   list.push("timer")
		if (ClockState.swStarted)                      list.push("stopwatch")
		if (ShellState.screenRecord && !ScreenRecService.recording) list.push("record_setup")
		if (ScreenRecService.recording)           list.push("record_active")

		root._items = list

		var idx = list.indexOf(currentType)
		if (idx < 0) idx = 0

		if (autoScrollType) {
			var nIdx = list.indexOf(autoScrollType)
			if (nIdx >= 0) {
				// Screen rec always takes priority — scroll regardless of where we are.
				// Other items only auto-scroll when coming from "title".
				var isScreenRec = (autoScrollType === "record_setup" ||
				autoScrollType === "record_active")
				if (isScreenRec || currentType === "title")
				idx = nIdx
			}
		}

		root._carouselIndex = idx
		statusList.contentY = idx * root._itemStride
	}

	// Force-scroll to a specific type regardless of where the user is
	function _forceScrollTo(type) {
		var idx = root._items.indexOf(type)
		if (idx < 0) return
		root._carouselIndex = idx
		statusList.contentY = idx * root._itemStride
	}

	onPlayerChanged: _rebuildItems(player !== null ? "music" : null)

	// ── State monitor — timer urgency + carousel transitions ─────────────────
	readonly property bool timerUrgent:
	ClockState.timerRunning && ClockState.timerLeft <= 30 && ClockState.timerLeft > 0

	Connections {
		target: ClockState

		function onTimerRunningChanged() {
			root._rebuildItems(ClockState.timerRunning ? "timer" : null)
		}

		function onSwStartedChanged() {
			root._rebuildItems(ClockState.swStarted ? "stopwatch" : null)
			root._forceScrollTo("stopwatch")
		}

		function onTimerLeftChanged() {
			if (ClockState.timerRunning && ClockState.timerLeft === 30 || ClockState.timerRunning && ClockState.timerLeft === 10)
			root._forceScrollTo("timer")
		}
		
		function onTimerStartedChanged() {
			root._rebuildItems(ClockState.timerStarted ? "timer" : null)
			root._forceScrollTo("timer")
		}
	}

	Connections {
		target: ShellState
		function onScreenRecordChanged() {
			if (ShellState.screenRecord && !ScreenRecService.recording)
			root._rebuildItems("record_setup")
			else if (!ShellState.screenRecord)
			root._rebuildItems(null)
		}
	}

	Connections {
		target: ScreenRecService
		function onRecordingChanged() {
			if (ScreenRecService.recording)
			root._rebuildItems("record_active")
			else
			root._rebuildItems(null)
		}
	}

	// ── Scroll debounce ───────────────────────────────────────────────────────
	property bool _scrollBusy: false
	Timer {
		id: scrollCooldown
		interval: 250
		onTriggered: root._scrollBusy = false
	}

	// ── Carousel ──────────────────────────────────────────────────────────────
	Item {
		id: carousel
		anchors.fill: parent

		opacity: Popups.dashboardOpen ? 0 : 1
		visible: opacity > 0
		Behavior on opacity { NumberAnimation { duration: 150 } }

		WheelHandler {
			acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
			onWheel: function(event) {
				// Block scroll only during setup (not during active recording)
				if (ShellState.screenRecord && !ScreenRecService.recording) return
				if (root._scrollBusy) return
				root._scrollBusy = true
				scrollCooldown.restart()

				var maxIdx = root._items.length - 1
				if (event.angleDelta.y < 0)
					root._carouselIndex = Math.min(maxIdx, root._carouselIndex + 1)
				else
					root._carouselIndex = Math.max(0, root._carouselIndex - 1)

				statusList.contentY = root._carouselIndex * root._itemStride
			}
		}

		Component { id: titleItem;  NotchTitleItem {} }
		Component { id: musicItem;  NotchMusicItem { artUrl: root.artUrl } }
		Component {
			id: timerItem
			NotchCountItem {
				glyph:   "󰔟"
				display: ClockState.timerDisplay
				running: ClockState.timerRunning
				urgent:  root.timerUrgent
				onToggled: ClockState.toggleTimer()
				onReset:   ClockState.resetTimer()
			}
		}
		Component {
			id: stopwatchItem
			NotchCountItem {
				glyph:   ""
				display: ClockState.swDisplay
				running: ClockState.swRunning
				onToggled: ClockState.toggleStopwatch()
				onReset:   ClockState.resetStopwatch()
			}
		}
		Component { id: recordSetupItem;  NotchRecordSetupItem {} }
		Component { id: recordActiveItem; NotchRecordActiveItem {} }

		readonly property var _components: ({
			title:         titleItem,
			music:         musicItem,
			timer:         timerItem,
			stopwatch:     stopwatchItem,
			record_setup:  recordSetupItem,
			record_active: recordActiveItem
		})
		// Items drawn inside the notch's flares get half a flare of margin each side.
		readonly property var _inset: ({ music: true, record_setup: true, record_active: true })

		ListView {
			id: statusList
			anchors.fill: parent
			orientation:  ListView.Vertical
			spacing:      15
			clip:         true
			snapMode:     ListView.SnapOneItem
			interactive:  false

			Behavior on contentY {
				NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
			}

			model: root._items

			delegate: Item {
				id: cell
				required property string modelData

				width:  Theme.cNotchMinWidth
				height: 30

				Loader {
					anchors.fill: parent
					anchors.leftMargin:  carousel._inset[cell.modelData] ? root.fw / 2 : 0
					anchors.rightMargin: carousel._inset[cell.modelData] ? root.fw / 2 : 0
					sourceComponent:     carousel._components[cell.modelData]
				}
			}
		}

		// ── Click to toggle dashboard ─────────────────────────────────────────
		// TapHandler has lower grab priority than child MouseAreas, so the
		// item buttons (stop, discard, …) handle their own clicks first.
		TapHandler {
			onTapped: {
				// Nothing during screen-rec setup — Esc / cancel handles it
				if (ShellState.screenRecord && !ScreenRecService.recording) return
				Popups.toggle("dashboard", QsWindow.window?.screen?.name ?? "")
			}
		}
	}
}
