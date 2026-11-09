import QtQuick
import "../../"
import "../../components"
import "../../components/sliders"
import "../"

// QuickSettings — the dashboard's right column: brightness slider and the
// scrollable grid of toggle tiles, plus the shader picker of the Filter tile.
// Layout only: the state and actions live in BrightnessService,
// QuickToggleService, HotspotService, ScreenFilterService, ShellState,
// FocusModeService and ScreenRecService.

StatCard {
    id: root
    padding: 0
    focus: true

    property bool filterPickerOpen: false

    function _openFilterPicker() {
        ScreenFilterService.refreshList()
        filterPickerOpen = true
    }

    Connections {
        target: Popups
        function onDashboardOpenChanged() {
            if (!Popups.dashboardOpen) root.filterPickerOpen = false
        }
    }

    Column {
        anchors { fill: parent; margins: 12 }
        spacing: 0

        BrightnessSlider { width: parent.width }

        Rectangle {
            width: parent.width; height: 1
            color: Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.08)
        }
        Item { width: parent.width; height: 8 }

        Text {
            id: qsLbl; width: parent.width
            text: "QUICK SETTINGS"; font.pixelSize: 9; font.weight: Font.Bold
            color: Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.55)
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
                    readonly property bool wifiShown: QuickToggleService.wifiOn && !HotspotService.on

                    QuickToggleTile {
                        width: tileGrid.btnW; height: tileGrid.btnH
                        on: tileGrid.wifiShown
                        icon: tileGrid.wifiShown ? "󰤨" : "󰤭"; label: "Wi-Fi"
                        sublabel: tileGrid.wifiShown && QuickToggleService.wifiSSID !== ""
                                  ? QuickToggleService.wifiSSID
                                  : (HotspotService.on ? "Used by Hotspot" : "")
                        onToggled: QuickToggleService.toggleWifi()
                    }
                    QuickToggleTile {
                        width: tileGrid.btnW; height: tileGrid.btnH
                        on: QuickToggleService.btOn
                        icon: QuickToggleService.btOn ? "󰂱" : "󰂲"; label: "Bluetooth"
                        sublabel: QuickToggleService.btOn && QuickToggleService.btDevice !== ""
                                  ? QuickToggleService.btDevice : ""
                        onToggled: QuickToggleService.toggleBluetooth()
                    }
                    QuickToggleTile {
                        width: tileGrid.btnW; height: tileGrid.btnH
                        on: QuickToggleService.airplaneOn; icon: "󰀝"; label: "Airplane Mode"
                        onToggled: QuickToggleService.toggleAirplane()
                    }
                    QuickToggleTile {
                        width: tileGrid.btnW; height: tileGrid.btnH
                        on: HotspotService.on || HotspotService.busy
                        icon: "󰀃"; label: "Hotspot"
                        sublabel: HotspotService.label
                        onToggled: HotspotService.toggle()
                    }
                    QuickToggleTile {
                        width: tileGrid.btnW; height: tileGrid.btnH
                        on: QuickToggleService.nightLightOn; icon: "󰖐"; label: "Night Light"
                        onToggled: QuickToggleService.toggleNightLight()
                    }
                    QuickToggleTile {
                        width: tileGrid.btnW; height: tileGrid.btnH
                        on: QuickToggleService.caffeineOn; icon: "󰅶"; label: "Caffeine"
                        onToggled: QuickToggleService.toggleCaffeine()
                    }
                    QuickToggleTile {
                        width: tileGrid.btnW; height: tileGrid.btnH
                        on: ShellState.focusMode
                        icon: ShellState.focusMode ? "󱃕" : "󰍻"; label: "Focus Mode"
                        onToggled: FocusModeService.toggle()
                    }
                    QuickToggleTile {
                        width: tileGrid.btnW; height: tileGrid.btnH
                        on: ShellState.dnd; icon: ShellState.dnd ? "󰂛" : "󰂚"
                        label: "Do Not Disturb"
                        onToggled: ShellState.dnd = !ShellState.dnd
                    }
                    QuickToggleTile {
                        width: tileGrid.btnW; height: tileGrid.btnH
                        on:    ShellState.screenRecord || ScreenRecService.recording
                        icon:  ScreenRecService.recording ? "⏹" : "󰻂"
                        label: ScreenRecService.recording ? "Recording" : "Screen Capture"
                        onToggled: {
                            if (ScreenRecService.recording) {
                                ScreenRecService.stopRecording()
                            } else if (ShellState.screenRecord) {
                                ScreenRecService.cancelSetup()
                            } else {
                                Popups.closeAll()
                                ShellState.screenRecord = true
                            }
                        }
                    }
                    // Filter tile — opens the picker, does not toggle directly
                    QuickToggleTile {
                        width: tileGrid.btnW; height: tileGrid.btnH
                        on:       ScreenFilterService.current !== ""
                        icon:     "󱡓"; label: "Filter"
                        sublabel: ScreenFilterService.current
                        onToggled: root._openFilterPicker()
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
