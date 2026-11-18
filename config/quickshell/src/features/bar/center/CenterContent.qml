import QtQuick
import Quickshell
import qs.src.services.media
import qs.src.state
import qs.src.theme
// CenterContent — the centre notch's scrollable carousel ("dynamic island").
//
// The items come from NotchItems: the active ones, by priority, each its own
// component (Notch*Item.qml, next to this file). When an item becomes active
// the carousel scrolls to it if its spec says so ("always", or "fromTitle":
// only while the carousel is on the first item); an item can also ask with
// requestScroll(force).

Item {
	// Set by the Dynamic Surface host (#39); contents adopt it progressively.
	property real localScale: 1.0

	id: root

	width:  Theme.cNotchMinWidth
	height: 30

	// DynamicSurface sizes the centre notch from it.
	readonly property int fw: Theme.notchRadius
	readonly property int requiredWidth: Theme.cNotchMinWidth

	NotchItems { id: registry }

	// ── Dynamic item list ─────────────────────────────────────────────────────
	property var  _items:         ["title"]
	property int  _carouselIndex: 0
	readonly property real _itemStride: 45  // 30px height + 15px spacing

	readonly property var _specs: {
		const m = {}
		for (let i = 0; i < registry.items.length; i++) m[registry.items[i].key] = registry.items[i]
		return m
	}

	// Rebuilds the list of active items; with `scrollTo`, scrolls to that item
	// (`force`: from anywhere, otherwise only from the first item).
	function _rebuildItems(scrollTo, force) {
		const currentType = (_items.length > _carouselIndex) ? _items[_carouselIndex] : _items[0]

		const list = Array.from(registry.items)
			.filter(it => it.active)
			.sort((a, b) => a.priority - b.priority)
			.map(it => it.key)
		root._items = list

		let idx = list.indexOf(currentType)
		if (idx < 0) idx = 0

		if (scrollTo) {
			const nIdx = list.indexOf(scrollTo)
			if (nIdx >= 0 && (force || currentType === list[0])) idx = nIdx
		}

		root._carouselIndex = idx
		statusList.contentY = idx * root._itemStride
	}

	Instantiator {
		model: registry.items
		delegate: Connections {
			required property var modelData
			target: modelData
			function onActiveChanged() {
				const it = modelData
				if (it.active && it.autoScroll !== "none") root._rebuildItems(it.key, it.autoScroll === "always")
				else root._rebuildItems(null, false)
			}
			function onRequestScroll(force) { root._rebuildItems(modelData.key, force) }
		}
	}

	Component.onCompleted: _rebuildItems(null, false)

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
				if (ShellModes.screenRecord && !ScreenRecService.recording) return
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
					anchors.leftMargin:  root._specs[cell.modelData]?.inset ? root.fw / 2 : 0
					anchors.rightMargin: root._specs[cell.modelData]?.inset ? root.fw / 2 : 0
					sourceComponent:     root._specs[cell.modelData]?.component ?? null
				}
			}
		}

		// ── Click to toggle dashboard ─────────────────────────────────────────
		// TapHandler has lower grab priority than child MouseAreas, so the
		// item buttons (stop, discard, …) handle their own clicks first.
		TapHandler {
			onTapped: {
				// Nothing during screen-rec setup — Esc / cancel handles it
				if (ShellModes.screenRecord && !ScreenRecService.recording) return
				Popups.toggle("dashboard", QsWindow.window?.screen?.name ?? "")
			}
		}
	}
}
