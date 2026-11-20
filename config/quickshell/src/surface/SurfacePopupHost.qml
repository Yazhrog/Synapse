import QtQuick
import qs.src.services.media
import qs.src.state
import qs.src.theme
// SurfacePopupHost — the interactive popups of a DynamicSurface.
//
// One clip item per PopupSpec of the manifest, following its region's
// animated rectangle (so the content appears to grow out of the frame) and
// fading with it. Contents are created on this screen the first time they
// open here, then kept; a content that declares `surface` / `screenName`
// gets them. The scope gets keyboard focus while one is open; Escape closes
// the popup from anywhere inside.
//
// Lifecycle (SurfaceState): on `opening` here, once the compositor has given
// the surface the keyboard, the spec's focus() picks the item to focus (the
// scope itself without one); on `closed` here, after the close animation,
// the spec's afterClose() runs.

FocusScope {
    id: host

    // The DynamicSurface: popups, open content, region rects
    required property var surface

    // key → loaded content item (reassigned, so bindings on it update)
    property var items: ({})
    property var _loaded: ({})

    Keys.onEscapePressed: {
        Popups.closeAll()
        if (host.surface.recSetup) ScreenRecService.cancelSetup()
    }

    Repeater {
        model: host.surface.popups
        delegate: Item {
            id: regionClip
            required property var modelData
            readonly property var  spec: modelData
            readonly property rect r:    host.surface.regionRect(spec.region)
            x: r.x; y: r.y; width: r.width; height: r.height
            clip:    true
            visible: opacity > 0
            opacity: host.surface.openContent === spec.key ? 1 : 0
            Behavior on opacity { Fade {} }

            Loader {
                readonly property rect p: regionClip.spec.place(host.surface, regionClip.width, regionClip.height)
                x: p.x; y: p.y; width: p.width; height: p.height
                active:          !!host._loaded[regionClip.spec.key]
                sourceComponent: regionClip.spec.component
                onLoaded: {
                    if ("surface" in item)    item.surface    = host.surface
                    if ("screenName" in item) item.screenName = Qt.binding(() => host.surface.screenName)
                    const items = Object.assign({}, host.items)
                    items[regionClip.spec.key] = item
                    host.items = items
                }
            }
        }
    }

    function _here(screen) { return screen === host.surface.screenName }

    Connections {
        target: SurfaceState
        function onOpening(key, screen) {
            if (!host._here(screen) || !host.surface.specs[key]) return
            if (!host._loaded[key]) {
                const loaded = Object.assign({}, host._loaded)
                loaded[key] = true
                host._loaded = loaded
            }
            focusTimer.key = key
            focusTimer.restart()
        }
        function onClosed(key, screen) {
            if (!host._here(screen)) return
            const spec = host.surface.specs[key], item = host.items[key]
            if (spec && spec.afterClose && item && !SurfaceState.isOpenOn(key, screen)) spec.afterClose(item)
        }
    }

    Connections {
        target: host.surface
        function onWantsKeyboardChanged() {
            if (host.surface.wantsKeyboard && !host.surface.openSpec) {
                focusTimer.key = ""
                focusTimer.restart()
            }
        }
    }

    Timer {
        id: focusTimer
        property string key: ""
        interval: 50
        onTriggered: {
            const spec = host.surface.specs[key], item = host.items[key]
            if (spec && spec.focus && item && host.surface.openContent === key) spec.focus(item)
            else host.forceActiveFocus()
        }
    }
}
