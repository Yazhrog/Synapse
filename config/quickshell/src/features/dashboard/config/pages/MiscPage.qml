import QtQuick
import qs.src.components.settings
import qs.src.features.dashboard.config.controls
import qs.src.services.system
// MiscPage — Config → Misc.
//
// Currently just the update settings. The toggle goes through
// UpdateService.setAutoUpdate (not straight to Prefs) because turning
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

            PrefDropdown {
                key: "surfaceScale"
            }
        }

        SettingsGroup {
            title: "Updates"

            PrefToggle {
                key: "autoUpdate"
                autoWrite:   false
                onToggled:   function(checked) { UpdateService.setAutoUpdate(checked) }
            }

            SettingsDivider {}

            SettingsButton {
                label:       "Check for updates now"
                description: UpdateService.updateAvailable
                    ? "Update pending: " + UpdateService.summary
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
