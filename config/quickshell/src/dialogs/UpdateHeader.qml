import QtQuick
import qs.src.services.system
import qs.src.theme
// UpdateHeader — UpdatePopup's title row: a state icon (spinning while
// checking or updating) and the state's title.
Row {
    spacing: 10

    Text {
        id: headerIcon
        anchors.verticalCenter: parent.verticalCenter
        font.pixelSize: 18
        text: UpdateService.updating || UpdateService.checking ? "󰑐"
            : UpdateService.updateSuccess                      ? "󰄬"
            : UpdateService.hasConflict                        ? "󰙨"
            : UpdateService.lastError !== ""                   ? "󰅙"
            : "󰑓"
        // Only the error state gets a distinct (destructive-style) color,
        // matching ConfirmDialog's convention of reserving red for the one
        // negative case rather than tinting every state a different hue.
        color: (UpdateService.lastError !== "" && !UpdateService.updating)
             ? "#cc3a3a"
             : Theme.color.accent
        Behavior on color { ColorAnimation { duration: 200 } }

        RotationAnimator {
            target:      headerIcon
            from:        0; to: 360
            duration:    900
            loops:       Animation.Infinite
            running:     UpdateService.updating || UpdateService.checking
            easing.type: Easing.Linear
            // Stopping leaves the icon at whatever angle it reached:
            // straighten it, or the next state's icon (✓, ✕) shows tilted.
            onRunningChanged: if (!running) headerIcon.rotation = 0
        }
    }

    Text {
        anchors.verticalCenter: parent.verticalCenter
        font.pixelSize: 13
        font.weight:    Font.DemiBold
        color:          Theme.color.text
        text: UpdateService.updating      ? "Updating…"
            : UpdateService.updateSuccess ? "Update Complete"
            : UpdateService.hasConflict   ? "Conflict Detected"
            : UpdateService.lastError !== "" && !UpdateService.updating
                                          ? "Update Failed"
            : "Synapse Update Available"
    }
}
