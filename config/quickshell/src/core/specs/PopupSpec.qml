import QtQuick

// PopupSpec — everything the shell needs to know about one popup.
//
// One spec file per popup (features/<feature>/<Feature>Popup.qml), listed in
// app/PopupManifest.qml. SurfaceState takes the keys and regions from the
// manifest, the Dynamic Surface sizes, places and focuses the content from
// it, and Popups its page state; nothing else names a popup's region or size.
//
//   PopupSpec {
//       key:    "clipboard"
//       region: "bottomRight"
//       size:   s => [s.px(420), s.px(560)]
//       place:  (s, w, h) => Qt.rect(s.px(10), s.px(8), s.px(410), s.px(544))
//       focus:  item => item.forceActiveFocus()
//       component: Component { ClipboardView {} }
//   }
//
// Functions get the DynamicSurface `s` (px(), borderWidth, notchRadius, …)
// and, for size(), the loaded content `item` (null until it first opens):
//   size(s, item)       the region's target size in px —
//                         top / right:                [width, bottom y]
//                         leftCenter / rightCenter:   [depth, height]
//                         bottomCenter / bottomRight: [width, height]
//   place(s, w, h)      where the content goes inside the region's clip item
//   focus(item)         gives the keyboard to the content once it opens
//                       (null: the popup host keeps it; Escape closes)
//   afterClose(item)    runs once it is closed (after the close animation)
// The loaded content gets `surface` and `screenName` if it declares them.
QtObject {
    required property string key
    required property string region     // top, right, leftCenter, rightCenter, bottomCenter, bottomRight
    property Component component: null
    property var size:  (s, item) => [0, 0]
    property var place: (s, w, h) => Qt.rect(0, 0, w, h)
    property var focus: null            // function(item)
    property var afterClose: null       // function(item)

    // Popups with pages: their PageSpec registry, the Popups property
    // holding the page, and the PrefsService key of the page to open on
    // ("last" = keep the page).
    property var    pages:           []

    // Toggle actions (app/ActionManifest.qml generates them): `action` toggles
    // the popup, each page's PageSpec.action opens it on that page; both go
    // in the keybinds page under `actionGroup`.
    property string action:      ""
    property string actionLabel: key
    property string actionGroup: "Popups"
    property string pageProp:        ""
    property string defaultPagePref: ""
}
