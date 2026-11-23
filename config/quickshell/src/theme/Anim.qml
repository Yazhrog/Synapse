import QtQuick

// Anim — a NumberAnimation on the motion tokens (Theme.motion): `normal`
// duration and the `standard` curve unless the user overrides them.
//   Behavior on width { Anim { duration: Theme.motion.slow; easing.type: Theme.motion.emphasized } }
NumberAnimation {
    duration:    Theme.motion.normal
    easing.type: Theme.motion.standard
}
