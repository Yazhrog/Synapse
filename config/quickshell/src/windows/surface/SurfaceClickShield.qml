import QtQuick
import "../../"

// SurfaceClickShield — closes the open popup on a click outside it (#42).
//
// On the screen owning the open popup (switching monitor closes it via
// ShellHost), the whole surface takes clicks while `active`, and a click
// outside the popup, the bar, the borders and the screen-recording options
// closes it. It sits below everything else, so the popups and the bar still
// get their own clicks first.

MouseArea {
    id: shield

    // The DynamicSurface: style, border, notch and region geometry
    required property var  surface
    // The screen-recording options strip, when shown
    property Item          recOptions: null

    enabled:         surface.shieldActive
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    onClicked: function(mouse) {
        if (shield._insideFrameOrPopup(mouse.x, mouse.y)) return
        Popups.closeAll()
    }

    function _inRect(r, x, y) {
        return x >= r.x && x <= r.x + r.width && y >= r.y && y <= r.y + r.height
    }

    function _insideFrameOrPopup(x, y) {
        const s = surface
        if (s.framed && (x < s.borderWidth || x > s.width - s.borderWidth || y < s.borderWidth || y > s.height - s.borderWidth))
            return true
        if (s.barStyle === "bar" && y < s.notchBottom)
            return true
        if (_inRect(Qt.rect(0, 0, s.lWidth, s.notchBottom), x, y)
                || _inRect(Qt.rect((s.width - s.cWidth) / 2, 0, s.cWidth, s.centerBottom), x, y)
                || _inRect(Qt.rect(s.width - s.rWidth, 0, s.rWidth, s.rightBottom), x, y))
            return true
        if (recOptions && recOptions.visible && _inRect(Qt.rect(recOptions.x, recOptions.y, recOptions.width, recOptions.height), x, y))
            return true
        return s.openSpec !== null && _inRect(s.regionRect(s.openSpec.region), x, y)
    }
}
