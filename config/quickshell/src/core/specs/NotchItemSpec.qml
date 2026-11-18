import QtQuick

// NotchItemSpec — one item of the center notch's carousel
// (features/bar/center/NotchItems.qml).
//
// Shown while `active`, ordered by `priority`. When it becomes active the
// carousel scrolls to it: "always", "fromTitle" (only if the carousel is on
// the first item) or "none". An item can also ask for the carousel with
// requestScroll(force) (force: from anywhere; otherwise only from the first
// item). `inset` gives it half a notch flare of margin on each side.
QtObject {
    required property string key
    property int    priority:   0
    property bool   active:     true
    property string autoScroll: "none"
    property bool   inset:      false
    property Component component: null

    signal requestScroll(bool force)
}
