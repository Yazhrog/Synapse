import QtQuick
import qs.src.core.specs
import qs.src.state
import qs.src.theme
// The audio popup: a bump on the right border, as wide as its page.
PopupSpec {
    id: spec
    readonly property AudioPages _registry: AudioPages {}
    key:    "audio"
    region: "rightCenter"
    actionGroup: "Audio Tabs"
    pages:           _registry.pages
    pageProp:        "audioPage"
    defaultPagePref: "defaultAudioPage"

    function _width(s, item) { return s.px(_registry.widthOf(item ? item.page : Popups.audioPage)) }

    size:   (s, item) => [spec._width(s, item), s.px(Theme.frame.sideRegionHeight)]
    place:  (s, w, h) => Qt.rect(s.px(10), s.px(6), w - s.px(16), h - s.px(12))
    afterClose: item => item.reset()
    component: Component { AudioControl {} }
}
