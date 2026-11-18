import QtQuick

// TileSpec — one Quick Settings tile (features/dashboard/home/QuickTiles.qml),
// bound to a service's state and intents.
//
//   TileSpec { key: "caffeine"; label: "Caffeine"; icon: "󰅶"
//              on: QuickToggleService.caffeineOn
//              toggle: host => QuickToggleService.toggleCaffeine() }
//
// toggle(host) gets the Quick Settings card (for tiles that open something
// inside it). `indicator` marks tiles the bar may show as indicators (#24).
QtObject {
    required property string key
    property string label:    key
    property string icon:     ""
    property bool   on:       false
    property string sublabel: ""
    property var    toggle:   host => {}
    property bool   indicator: false
}
