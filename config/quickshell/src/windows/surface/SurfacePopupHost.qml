import QtQuick
import "../../"
import "../../theme/"
import "../../services/"

// SurfacePopupHost — the interactive popups of a DynamicSurface.
//
// One clip item per content, following its region's animated rectangle
// (so the content appears to grow out of the frame) and fading with its
// content flag. Contents are created on this screen the first time they
// open here, then kept. The scope gets keyboard focus while one is open;
// Escape closes the popup from anywhere inside. Once the compositor has
// given the surface the keyboard, the open content's focus() picks the
// item to focus; a content's afterClose() runs after its close animation.

FocusScope {
    id: host

    // The DynamicSurface: contents table, open content, region rects
    required property var surface

    property var _loaded: ({})
    property var _items:  ({})

    Keys.onEscapePressed: {
        Popups.closeAll()
        if (host.surface.recSetup) ScreenRecService.cancelSetup()
    }

    Repeater {
        model: host.surface.contentKeys
        delegate: Item {
            id: regionClip
            required property string modelData
            readonly property var  spec: host.surface.contents[modelData]
            readonly property rect r:    host.surface.regionRect(spec.region)
            x: r.x; y: r.y; width: r.width; height: r.height
            clip:    true
            visible: opacity > 0
            opacity: host.surface.openContent === modelData ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Metrics.regionFadeDuration } }

            Loader {
                readonly property rect p: regionClip.spec.place(regionClip.width, regionClip.height)
                x: p.x; y: p.y; width: p.width; height: p.height
                active:          !!host._loaded[regionClip.modelData]
                sourceComponent: regionClip.spec.component
                onLoaded:        host._items[regionClip.modelData] = item
            }
        }
    }

    property string _lastContent: "none"

    Connections {
        target: host.surface
        function onOpenContentChanged() {
            const s = host.surface
            const prev = host._lastContent
            host._lastContent = s.openContent
            if (prev !== "none" && s.contents[prev] && s.contents[prev].afterClose) {
                afterCloseTimer.key = prev
                afterCloseTimer.restart()
            }
            // (openSpec may not be re-evaluated yet inside this handler.)
            if (!s.contents[s.openContent]) return
            if (!host._loaded[s.openContent]) {
                const loaded = Object.assign({}, host._loaded)
                loaded[s.openContent] = true
                host._loaded = loaded
            }
            focusTimer.restart()
        }
        function onWantsKeyboardChanged() {
            if (host.surface.wantsKeyboard && !host.surface.openSpec) focusTimer.restart()
        }
    }

    Timer {
        id: focusTimer
        interval: 50
        onTriggered: {
            const spec = host.surface.contents[host.surface.openContent]
            const item = host._items[host.surface.openContent]
            if (spec && item) spec.focus(item)
            else host.forceActiveFocus()
        }
    }

    Timer {
        id: afterCloseTimer
        property string key: ""
        interval: Theme.animDuration + 20
        onTriggered: {
            const item = host._items[key]
            if (item && host.surface.openContent !== key) host.surface.contents[key].afterClose(item)
        }
    }
}
