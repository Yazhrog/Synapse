import QtQuick
import qs.src.core.specs
import qs.src.theme
// The power menu: a bump on the left border.
PopupSpec {
    key:    "powerMenu"
    region: "leftCenter"
    size:   s => [s.px(Metrics.powerMenuWidth + 2 * Metrics.powerMenuPadding),
                  s.px(Metrics.powerMenuHeight + 2 * Metrics.powerMenuPadding)]
    place:  (s, w, h) => Qt.rect(s.px(4), s.px(Metrics.powerMenuPadding),
                                 s.px(Metrics.powerMenuWidth), s.px(Metrics.powerMenuHeight))
    focus:  item => item.reset()
    component: Component { PowerMenu {} }
}
