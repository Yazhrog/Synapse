// keynames.js — Qt key events → the names Hyprland binds use.
.pragma library

// Modifier keys on their own (a bind needs a non-modifier key).
function isModifier(k) {
    return k === Qt.Key_Shift    || k === Qt.Key_Control  ||
           k === Qt.Key_Meta     || k === Qt.Key_Alt      ||
           k === Qt.Key_Super_L  || k === Qt.Key_Super_R  ||
           k === Qt.Key_Hyper_L  || k === Qt.Key_Hyper_R  ||
           k === Qt.Key_AltGr    || k === Qt.Key_CapsLock ||
           k === Qt.Key_NumLock  || k === Qt.Key_ScrollLock
}

// Modifier flags → "SUPER + SHIFT + CTRL + ALT" (that order), "" for none.
function modsText(flags) {
    var p = []
    if (flags & Qt.MetaModifier)    p.push("SUPER")
    if (flags & Qt.ShiftModifier)   p.push("SHIFT")
    if (flags & Qt.ControlModifier) p.push("CTRL")
    if (flags & Qt.AltModifier)     p.push("ALT")
    return p.join(" + ")
}

// Key code → Hyprland key name ("A", "F5", "Prior", "bracketleft"…), "" if unsupported.
function keyName(k) {
    if (isModifier(k)) return ""
    if (k >= Qt.Key_A && k <= Qt.Key_Z)    return String.fromCharCode(k)
    if (k >= Qt.Key_0 && k <= Qt.Key_9)    return String.fromCharCode(k)
    if (k >= Qt.Key_F1 && k <= Qt.Key_F35) return "F" + (k - Qt.Key_F1 + 1)
        var m = {}
        m[Qt.Key_Escape]       = "Escape"
        m[Qt.Key_Return]       = "Return"
        m[Qt.Key_Enter]        = "KP_Enter"
        m[Qt.Key_Tab]          = "Tab"
        m[Qt.Key_Backspace]    = "BackSpace"
        m[Qt.Key_Delete]       = "Delete"
        m[Qt.Key_Insert]       = "Insert"
        m[Qt.Key_Home]         = "Home"
        m[Qt.Key_End]          = "End"
        m[Qt.Key_PageUp]       = "Prior"
        m[Qt.Key_PageDown]     = "Next"
        m[Qt.Key_Left]         = "Left"
        m[Qt.Key_Right]        = "Right"
        m[Qt.Key_Up]           = "Up"
        m[Qt.Key_Down]         = "Down"
        m[Qt.Key_Space]        = "Space"
        m[Qt.Key_Print]        = "Print"
        m[Qt.Key_Pause]        = "Pause"
        m[Qt.Key_Minus]        = "minus"
        m[Qt.Key_Equal]        = "equal"
        m[Qt.Key_BracketLeft]  = "bracketleft"
        m[Qt.Key_BracketRight] = "bracketright"
        m[Qt.Key_Backslash]    = "backslash"
        m[Qt.Key_Semicolon]    = "semicolon"
        m[Qt.Key_Apostrophe]   = "apostrophe"
        m[Qt.Key_Comma]        = "comma"
        m[Qt.Key_Period]       = "period"
        m[Qt.Key_Slash]        = "slash"
        m[Qt.Key_QuoteLeft]    = "grave"
        return m[k] || ""
}
