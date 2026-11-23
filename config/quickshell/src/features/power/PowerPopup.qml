import QtQuick
import qs.src.core.specs
import qs.src.theme
// The power menu: a bump on the left border.
PopupSpec {
    key:    "powerMenu"
    region: "leftCenter"
    action: "PowerMenu-toggle"; actionLabel: "Power Menu"
    size:   s => [s.px(Theme.frame.powerMenuWidth + 2 * Theme.frame.powerMenuPadding),
                  s.px(Theme.frame.powerMenuHeight + 2 * Theme.frame.powerMenuPadding)]
    place:  (s, w, h) => Qt.rect(s.px(4), s.px(Theme.frame.powerMenuPadding),
                                 s.px(Theme.frame.powerMenuWidth), s.px(Theme.frame.powerMenuHeight))
    focus:  item => item.reset()
    component: Component { PowerMenu {} }
}
