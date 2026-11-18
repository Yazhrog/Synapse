import QtQuick
import qs.src.core.specs
import qs.src.theme
// The notification history: grows the right notch down to its list's height.
PopupSpec {
    key:    "notifications"
    region: "right"
    action: "notifications-toggle"; actionLabel: "Notifications"
    size:   (s, item) => [s.px(Theme.notificationsWidth + Theme.notchRadius) + s.borderWidth,
                          s.notchBottom + (item?.listHeight || 0) + s.px(2 * Theme.popupPadding + 4)]
    place:  (s, w, h) => Qt.rect(s.px(Theme.notchRadius + 4), s.px(4),
                                 s.px(Theme.notificationsWidth - 8), h)
    // Wrapped, so the Loader resizes the wrapper and the list keeps the
    // height it computes for itself (the region's size follows it).
    component: Component {
        Item {
            readonly property real listHeight: list.height
            NotificationList { id: list; width: parent.width }
        }
    }
}
