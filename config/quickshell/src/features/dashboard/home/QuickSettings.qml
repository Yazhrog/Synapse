import QtQuick
import qs.src.components.base
import qs.src.components.inputs
import qs.src.services.media
import qs.src.services.system
import qs.src.state
import qs.src.theme
// QuickSettings — the dashboard's right column: brightness slider and the
// scrollable grid of toggle tiles, plus the shader picker of the Filter tile.
// Layout only: the tiles come from QuickTiles, the state and actions from
// the services they bind.

StatCard {
    id: root
    padding: 0
    focus: true

    property bool filterPickerOpen: false

    QuickTiles { id: tiles }

    function openFilterPicker() {
        ScreenFilterService.refreshList()
        filterPickerOpen = true
    }

    PopupLifecycle {
        popup: "dashboard"
        onClosing: if (!Popups.dashboardOpen) root.filterPickerOpen = false   // not when it moves screen
    }

    Column {
        anchors { fill: parent; margins: 12 }
        spacing: 0

        BrightnessSlider {
            width:   parent.width
            value:   BrightnessService.value
            onMoved: v => BrightnessService.set(v)
        }

        Rectangle {
            width: parent.width; height: 1
            color: Qt.rgba(Theme.color.text.r, Theme.color.text.g, Theme.color.text.b, 0.08)
        }
        Item { width: parent.width; height: 8 }

        Text {
            id: qsLbl; width: parent.width
            text: "QUICK SETTINGS"; font.pixelSize: 9; font.weight: Font.Bold
            color: Qt.rgba(Theme.color.accent.r, Theme.color.accent.g, Theme.color.accent.b, 0.55)
        }
        Item { width: parent.width; height: 8 }

        // ── Tile grid ─────────────────────────────────────────────────────────
        Item {
            width:  parent.width
            height: root.height - 12 - 52 - 1 - 8 - qsLbl.height - 8

            Flickable {
                id: flick
                anchors.fill:   parent
                contentWidth:   width
                contentHeight:  tileGrid.implicitHeight + 8
                clip:           true
                boundsBehavior: Flickable.StopAtBounds

                Grid {
                    id: tileGrid
                    width: flick.width
                    columns: 2; spacing: 6

                    readonly property real btnW: (width - spacing) / 2
                    readonly property real btnH: btnW * 0.85

                    Repeater {
                        model: tiles.tiles
                        delegate: QuickToggleTile {
                            required property var modelData
                            width: tileGrid.btnW; height: tileGrid.btnH
                            on:       modelData.on
                            icon:     modelData.icon
                            label:    modelData.label
                            sublabel: modelData.sublabel
                            onToggled: modelData.toggle(root)
                        }
                    }
                }
            }
        }
    }

    // Floats over the bottom-right tiles; z: 20 renders it over the grid.
    QuickFilterPicker {
        anchors { right: parent.right; bottom: parent.bottom; rightMargin: 12; bottomMargin: 12 }
        open: root.filterPickerOpen
        returnFocusTo: root
        onCloseRequested: root.filterPickerOpen = false
    }

    // Tap outside the picker to close it
    TapHandler {
        enabled: root.filterPickerOpen
        onTapped: root.filterPickerOpen = false
    }
}
