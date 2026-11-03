import QtQuick
import "../../"
import "../../components"

// MiscPage — Config → Misc.
//
// Currently just the update settings. The toggle goes through
// UpdateService.setAutoUpdate (not straight to PrefsService) because turning
// checks off also clears a pending update popup.
Item {
    id: root

    Column {
        anchors {
            top:         parent.top
            left:        parent.left
            right:       parent.right
            topMargin:   14
            leftMargin:  16
            rightMargin: 16
        }
        spacing: 14

        SettingsGroup {
            title: "Display"

            SettingsDropdown {
                label:       "Surface scale"
                description: "Scales the frame and popup sizes. Popup contents don't scale yet."
                prefKey:     "surfaceScale"
                options: [
                    { value: "off",  label: "Off"  },
                    { value: "auto", label: "Auto" },
                    { value: "1.25", label: "125%" },
                    { value: "1.5",  label: "150%" }
                ]
            }
        }

        SettingsGroup {
            title: "Updates"

            SettingsToggle {
                label:       "Check for updates on startup"
                description: "Looks for new commits on origin/main 30s after login."
                prefKey:     "autoUpdate"
                autoWrite:   false
                onToggled:   function(checked) { UpdateService.setAutoUpdate(checked) }
            }

            SettingsDivider {}

            SettingsButton {
                label:       "Check for updates now"
                description: UpdateService.updateAvailable
                    ? UpdateService.commitsBehind + " update(s) pending"
                    : "Up to date"
                buttonText:  UpdateService.checking ? "Checking…" : "Check Now"
                busy:        UpdateService.checking || UpdateService.updating
                onActivated: UpdateService.check()
            }

            SettingsDivider {}

            // Every config in ~/.config symlinks into this path, so it is
            // what `git pull` updates.
            SettingsRow {
                label:           "Source repository"
                description:     UpdateService._dir === "" ? "resolving…" : UpdateService._dir
                monoDescription: true
            }
        }
    }
}
